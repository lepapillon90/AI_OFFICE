import 'package:ai_office/data/activity_repository.dart';
import 'package:ai_office/data/chat_message.dart';
import 'package:ai_office/data/chat_repository.dart';
import 'package:ai_office/data/company_repository.dart';
import 'package:ai_office/data/multiplayer_channel.dart';
import 'package:ai_office/data/npc_command_service.dart';
import 'package:ai_office/data/npc_document_repository.dart';
import 'package:ai_office/data/npc_task_repository.dart';
import 'package:ai_office/data/npc_usage_repository.dart';
import 'package:ai_office/game/activity/activity_event.dart';
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
    required this.multiplayer,
    required this.companyId,
  });

  final OfficeGame game;
  final bool canManageRoster;
  final MultiplayerChannel multiplayer;
  final String companyId;
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
  final _npcCommandService = NpcCommandService(Supabase.instance.client);
  final _taskRepository = NpcTaskRepository(Supabase.instance.client);
  final _usageRepository = NpcUsageRepository(Supabase.instance.client);
  final _documentRepository = NpcDocumentRepository(Supabase.instance.client);
  final _activityRepository = ActivityRepository(Supabase.instance.client);
  MultiplayerChannel? _multiplayerToDispose;

  Future<_LoadedSession> _load() async {
    final companyId = await widget.repository.ensureCompany();
    final role = await widget.repository.fetchRole(companyId);
    final employees = await widget.repository.fetchEmployees(companyId);
    // Falls back to no history rather than failing the whole session if
    // the `messages` table's migration hasn't been run yet.
    final chatHistory = await _chatRepository
        .fetchRecentMessages(companyId)
        .catchError((_) => <ChatMessage>[]);
    // Same fallback for the npc_tasks/npc_usage_events tables — see
    // docs/PHASE6_AI_EMPLOYEES.md's persistence section for the migration.
    final taskHistory = await _taskRepository
        .fetchRecentTasks(companyId)
        .catchError((_) => <NpcTask>[]);
    final usageSummaries = await _usageRepository
        .fetchUsageSummaries(companyId)
        .catchError((_) => <String, NpcUsageSummary>{});
    // Same fallback for the activity_events table — see
    // docs/PHASE7_ACTIVITY.md for the migration.
    final activityHistory = await _activityRepository
        .fetchRecentActivity(companyId)
        .catchError((_) => <ActivityEvent>[]);

    final multiplayer = MultiplayerChannel(
      client: Supabase.instance.client,
      companyId: companyId,
      userId: Supabase.instance.client.auth.currentUser!.id,
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
    );

    return _LoadedSession(
      game: game,
      canManageRoster: role.canManageRoster,
      multiplayer: multiplayer,
      companyId: companyId,
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
          onLogout: () => Supabase.instance.client.auth.signOut(),
          companyId: session.companyId,
          repository: widget.repository,
        );
      },
    );
  }
}
