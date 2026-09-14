import 'package:ai_office/data/activity_repository.dart';
import 'package:ai_office/data/board_repository.dart';
import 'package:ai_office/data/chat_attachment_repository.dart';
import 'package:ai_office/data/chat_message.dart';
import 'package:ai_office/data/chat_repository.dart';
import 'package:ai_office/data/company_repository.dart';
import 'package:ai_office/data/company_role.dart';
import 'package:ai_office/data/multiplayer_channel.dart';
import 'package:ai_office/data/npc_command_service.dart';
import 'package:ai_office/data/npc_document_repository.dart';
import 'package:ai_office/data/npc_task_repository.dart';
import 'package:ai_office/data/npc_usage_repository.dart';
import 'package:ai_office/data/slack_integration_repository.dart';
import 'package:ai_office/game/activity/activity_event.dart';
import 'package:ai_office/game/board/board_task.dart';
import 'package:ai_office/game/npc/ai_employee.dart';
import 'package:ai_office/game/npc/npc_task.dart';
import 'package:ai_office/game/npc/npc_usage.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:ai_office/screens/auth/login_screen.dart';
import 'package:ai_office/screens/office_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shows [LoginScreen] while signed out; once signed in, loads the user's
/// company and AI employee roster from Supabase and shows [OfficeScreen].
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _repository = CompanyRepository(Supabase.instance.client);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          return const LoginScreen();
        }
        return _CompanyLoader(
          key: ValueKey(session.user.id),
          repository: _repository,
        );
      },
    );
  }
}

class _LoadedSession {
  const _LoadedSession({
    required this.game,
    required this.canManageRoster,
    required this.canManageMembers,
    required this.multiplayer,
    required this.companyId,
    required this.slackRepository,
  });

  final OfficeGame game;
  final bool canManageRoster;
  final bool canManageMembers;
  final MultiplayerChannel multiplayer;
  final String companyId;
  final SlackIntegrationRepository slackRepository;
}

class _CompanyLoader extends StatefulWidget {
  const _CompanyLoader({super.key, required this.repository});

  final CompanyRepository repository;

  @override
  State<_CompanyLoader> createState() => _CompanyLoaderState();
}

class _CompanyLoaderState extends State<_CompanyLoader> {
  late final Future<_LoadedSession> _future = _load();
  final _chatRepository = ChatRepository(Supabase.instance.client);
  final _chatAttachmentRepository =
      ChatAttachmentRepository(Supabase.instance.client);
  final _npcCommandService = NpcCommandService(Supabase.instance.client);
  final _taskRepository = NpcTaskRepository(Supabase.instance.client);
  final _usageRepository = NpcUsageRepository(Supabase.instance.client);
  final _documentRepository = NpcDocumentRepository(Supabase.instance.client);
  final _activityRepository = ActivityRepository(Supabase.instance.client);
  final _boardRepository = BoardRepository(Supabase.instance.client);
  final _slackRepository = SlackIntegrationRepository(Supabase.instance.client);
  MultiplayerChannel? _multiplayerToDispose;

  Future<_LoadedSession> _load() async {
    final companyId = await widget.repository.ensureCompany();
    // These seven queries are all independent once companyId is known, so
    // they run concurrently rather than one round trip after another —
    // found during the Phase 7 ops review (docs/PHASE7_OPS_REVIEW.md) as a
    // real login-latency cost that had grown with each history/table added
    // this session. Each still falls back to an empty/default result
    // rather than failing the whole session if its table's migration
    // hasn't been run yet (see the referenced docs for each).
    final results = await Future.wait([
      widget.repository.fetchRole(companyId),
      widget.repository.fetchEmployees(companyId),
      _chatRepository
          .fetchRecentMessages(companyId)
          .catchError((_) => <ChatMessage>[]),
      _taskRepository.fetchRecentTasks(companyId).catchError((_) => <NpcTask>[]),
      _usageRepository
          .fetchUsageSummaries(companyId)
          .catchError((_) => <String, NpcUsageSummary>{}),
      _activityRepository
          .fetchRecentActivity(companyId)
          .catchError((_) => <ActivityEvent>[]),
      _boardRepository.fetchTasks(companyId).catchError((_) => <BoardTask>[]),
      _activityRepository
          .fetchLastReadAt(companyId, Supabase.instance.client.auth.currentUser!.id)
          .catchError((_) => null),
    ]);
    final role = results[0] as CompanyRole;
    final employees = results[1] as List<AiEmployee>;
    final chatHistory = results[2] as List<ChatMessage>;
    final taskHistory = results[3] as List<NpcTask>;
    final usageSummaries = results[4] as Map<String, NpcUsageSummary>;
    final activityHistory = results[5] as List<ActivityEvent>;
    final boardTasks = results[6] as List<BoardTask>;
    final activityReadAt = results[7] as DateTime?;

    final userId = Supabase.instance.client.auth.currentUser!.id;
    final multiplayer = MultiplayerChannel(
      client: Supabase.instance.client,
      companyId: companyId,
      userId: userId,
    );
    _multiplayerToDispose = multiplayer;

    final game = OfficeGame(
      employees: employees,
      onEmployeeChanged: (employee) =>
          widget.repository.upsertEmployee(companyId, employee),
      multiplayer: multiplayer,
      initialChatMessages: chatHistory,
      onChatMessageSent: (message) => _chatRepository
          .sendMessage(companyId, message)
          .catchError((_) {}),
      uploadChatAttachment: ({required fileName, required bytes}) async {
        try {
          return await _chatAttachmentRepository.upload(
            companyId: companyId,
            fileName: fileName,
            bytes: bytes,
          );
        } catch (_) {
          return null;
        }
      },
      resolveAttachmentUrl: (path) async {
        try {
          return await _chatAttachmentRepository.signedUrl(path);
        } catch (_) {
          return null;
        }
      },
      askEmployee: ({
        required employeeName,
        required employeeRole,
        required command,
        required history,
      }) =>
          _npcCommandService.ask(
        employeeName: employeeName,
        employeeRole: employeeRole,
        command: command,
        history: history,
        companyId: companyId,
      ),
      initialTasks: taskHistory,
      initialUsage: usageSummaries,
      onTaskChanged: (task) =>
          _taskRepository.upsertTask(companyId, task).catchError((_) {}),
      onUsageEvent: (employeeId, {required success, usage}) =>
          _usageRepository
              .recordEvent(companyId, employeeId, success: success, usage: usage)
              .catchError((_) {}),
      generateDocument: ({
        required employeeId,
        required employeeName,
        required taskId,
        required command,
        required result,
      }) =>
          _documentRepository.upload(
        companyId: companyId,
        employeeId: employeeId,
        employeeName: employeeName,
        taskId: taskId,
        command: command,
        result: result,
      ),
      resolveDocumentUrl: (path) => _documentRepository.signedUrl(path),
      initialActivity: activityHistory,
      onActivityLogged: (event) =>
          _activityRepository.logEvent(companyId, event).catchError((_) {}),
      initialActivityReadAt: activityReadAt,
      onActivityRead: (readAt) => _activityRepository
          .markRead(companyId, userId, readAt)
          .catchError((_) {}),
      notifySlack: (text) =>
          _slackRepository.notify(companyId, text).catchError((_) {}),
      initialBoardTasks: boardTasks,
      onBoardTaskChanged: (task) =>
          _boardRepository.upsertTask(companyId, task).catchError((_) {}),
      onBoardTaskDeleted: (taskId) =>
          _boardRepository.deleteTask(taskId).catchError((_) {}),
    );

    return _LoadedSession(
      game: game,
      canManageRoster: role.canManageRoster,
      canManageMembers: role.canManageMembers,
      multiplayer: multiplayer,
      companyId: companyId,
      slackRepository: _slackRepository,
    );
  }

  @override
  void dispose() {
    _multiplayerToDispose?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LoadedSession>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('회사 데이터를 불러오지 못했습니다.\n${snapshot.error}'),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final session = snapshot.data!;
        return OfficeScreen(
          game: session.game,
          canManageRoster: session.canManageRoster,
          canManageMembers: session.canManageMembers,
          onLogout: () => Supabase.instance.client.auth.signOut(),
          companyId: session.companyId,
          repository: widget.repository,
          slackRepository: session.slackRepository,
        );
      },
    );
  }
}
