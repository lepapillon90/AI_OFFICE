import 'dart:async';

import 'package:ai_office/data/chat_message.dart';
import 'package:ai_office/data/multiplayer_channel.dart';
import 'package:ai_office/data/remote_player_state.dart';
import 'package:ai_office/game/exterior_backdrop.dart';
import 'package:ai_office/game/floors/executive_map.dart';
import 'package:ai_office/game/floors/floor.dart';
import 'package:ai_office/game/floors/floor_layout.dart';
import 'package:ai_office/game/floors/project_room_map.dart';
import 'package:ai_office/game/interactions/computer_interaction.dart';
import 'package:ai_office/game/interactions/elevator_interaction.dart';
import 'package:ai_office/game/isometric/iso_lobby_scene.dart';
import 'package:ai_office/game/isometric/iso_projection.dart';
import 'package:ai_office/game/map/office_layout.dart';
import 'package:ai_office/game/map/office_map.dart';
import 'package:ai_office/game/multiplayer/remote_player_component.dart';
import 'package:ai_office/game/npc/ai_employee.dart';
import 'package:ai_office/game/npc/npc_component.dart';
import 'package:ai_office/game/npc/npc_placement.dart';
import 'package:ai_office/game/npc/npc_status.dart';
import 'package:ai_office/game/npc/npc_task.dart';
import 'package:ai_office/game/npc/npc_usage.dart';
import 'package:ai_office/game/npc/sample_employees.dart';
import 'package:ai_office/game/npc/workstation.dart';
import 'package:ai_office/game/player/office_player.dart';
import 'package:ai_office/game/player/player_profile.dart';
import 'package:ai_office/game/player/player_status.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Answers an `@employee command` chat message with that employee's reply.
///
/// [history] is the recent back-and-forth already had with this employee
/// (oldest first, `role` is `'user'` or `'assistant'`), so a handler backed
/// by an LLM can answer with multi-turn context instead of treating every
/// command as a one-off.
typedef NpcCommandHandler = Future<NpcCommandResult> Function({
  required String employeeName,
  required String employeeRole,
  required String command,
  required List<Map<String, String>> history,
});

/// Turns a successful `askEmployee` reply into a saved work document (e.g.
/// uploaded to Supabase Storage) and returns its storage path, or null if
/// no document was produced. Null outside a signed-in session (e.g. tests)
/// — tasks then simply have no [NpcTask.documentPath].
typedef DocumentGenerator = Future<String?> Function({
  required String employeeId,
  required String employeeName,
  required String taskId,
  required String command,
  required String result,
});

/// Resolves an [NpcTask.documentPath] to a URL the player can open (e.g. a
/// Supabase Storage signed URL). Null outside a signed-in session.
typedef DocumentUrlResolver = Future<String?> Function(String documentPath);

/// The interactive office world and its camera configuration.
class OfficeGame extends FlameGame
    with HasKeyboardHandlerComponents, ScrollDetector, ChangeNotifier {
  OfficeGame({
    List<AiEmployee>? employees,
    void Function(AiEmployee)? onEmployeeChanged,
    MultiplayerChannel? multiplayer,
    List<ChatMessage>? initialChatMessages,
    void Function(ChatMessage)? onChatMessageSent,
    NpcCommandHandler? askEmployee,
    List<NpcTask>? initialTasks,
    Map<String, NpcUsageSummary>? initialUsage,
    void Function(NpcTask task)? onTaskChanged,
    void Function(String employeeId, {required bool success, NpcUsage? usage})?
        onUsageEvent,
    DocumentGenerator? generateDocument,
    DocumentUrlResolver? resolveDocumentUrl,
  }) : this._(
          playerPosition: OfficeLayout.worldSize.clone() / 2,
          employees: employees,
          onEmployeeChanged: onEmployeeChanged,
          multiplayer: multiplayer,
          initialChatMessages: initialChatMessages,
          onChatMessageSent: onChatMessageSent,
          askEmployee: askEmployee,
          initialTasks: initialTasks,
          initialUsage: initialUsage,
          onTaskChanged: onTaskChanged,
          onUsageEvent: onUsageEvent,
          generateDocument: generateDocument,
          resolveDocumentUrl: resolveDocumentUrl,
        );

  OfficeGame.forTest({required Vector2 playerPosition})
      : this._(playerPosition: playerPosition);

  OfficeGame._({
    required Vector2 playerPosition,
    List<AiEmployee>? employees,
    this.onEmployeeChanged,
    this.multiplayer,
    List<ChatMessage>? initialChatMessages,
    this.onChatMessageSent,
    this.askEmployee,
    List<NpcTask>? initialTasks,
    Map<String, NpcUsageSummary>? initialUsage,
    this.onTaskChanged,
    this.onUsageEvent,
    this.generateDocument,
    this.resolveDocumentUrl,
  }) {
    _chatMessages = List.of(initialChatMessages ?? const []);
    _employees = List.of(employees ?? sampleEmployees);
    for (final task in initialTasks ?? const <NpcTask>[]) {
      _tasksByEmployee.putIfAbsent(task.employeeId, () => []).add(task);
    }
    if (initialUsage != null) {
      _usageByEmployee.addAll(initialUsage);
    }
    computers = _buildComputers()
      ..forEach((c) => c.priority = _furniturePriority);
    elevator = ElevatorInteraction(position: FloorLayouts.elevatorPosition)
      ..priority = _furniturePriority;
    player = OfficePlayer(
      position: playerPosition,
      onPositionChanged: _onPlayerMoved,
      onHoverChanged: _setPlayerHovered,
      onTap: openProfileCard,
    )..priority = _playerPriority;
    final npcs = _buildNpcs()..forEach((npc) => npc.priority = _npcPriority);
    final projectRoomNpcs = _buildFloorNpcs(Floor.projectRoom)
      ..forEach((npc) => npc.priority = _npcPriority);
    final executiveNpcs = _buildFloorNpcs(Floor.executive)
      ..forEach((npc) => npc.priority = _npcPriority);
    _floorComponents = {
      Floor.lobby: IsoLobbyScene().createComponents(),
      Floor.workspace: [OfficeMap(), ...computers, ...npcs],
      Floor.projectRoom: [ProjectRoomMap(), ...projectRoomNpcs],
      Floor.executive: [ExecutiveMap(), ...executiveNpcs],
    };
    _onPlayerMoved(player.position);
  }

  // Floor maps render at the default priority (0); these draw on top of
  // them so the elevator, NPCs, and player never appear "under the floor"
  // regardless of the order components are added/removed when switching
  // floors.
  static const _furniturePriority = 1;
  static const _npcPriority = 2;
  static const _playerPriority = 3;

  late final OfficePlayer player;
  late final List<ComputerInteraction> computers;
  late final ElevatorInteraction elevator;
  late final Map<Floor, List<Component>> _floorComponents;
  late List<AiEmployee> _employees;

  /// Called after [updateEmployee] applies a change, so the host app can
  /// persist it (e.g. to Supabase).
  final void Function(AiEmployee)? onEmployeeChanged;

  /// Shares this player's position/profile with other signed-in users in
  /// the same company, and reports theirs back. Null outside a signed-in
  /// session (e.g. tests).
  final MultiplayerChannel? multiplayer;
  final Map<String, RemotePlayerComponent> _remotePlayers = {};
  final Map<String, NpcComponent> _npcsByWorkstation = {};

  /// Called after [sendChatMessage] broadcasts a message, so the host app
  /// can persist it (e.g. to Supabase) for chat history.
  final void Function(ChatMessage)? onChatMessageSent;

  /// Answers an `@employee command` chat message with that AI employee's
  /// reply (e.g. via a Supabase Edge Function calling an LLM). Null outside
  /// a signed-in session (e.g. tests) — commands are then ignored.
  final NpcCommandHandler? askEmployee;
  late List<ChatMessage> _chatMessages;

  /// Called whenever a task is created (`pending`) or resolves
  /// (`success`/`error`), so the host app can upsert it (e.g. to
  /// Supabase's `npc_tasks` table). Null outside a signed-in session.
  final void Function(NpcTask task)? onTaskChanged;

  /// Called once per `askEmployee` attempt (including retries), so the
  /// host app can persist a usage event (e.g. to Supabase's
  /// `npc_usage_events` table). Null outside a signed-in session.
  final void Function(String employeeId, {required bool success, NpcUsage? usage})?
      onUsageEvent;

  /// Turns a successful reply into a saved work document — see
  /// [DocumentGenerator]. Null outside a signed-in session.
  final DocumentGenerator? generateDocument;

  /// Resolves an [NpcTask.documentPath] to an openable URL — see
  /// [DocumentUrlResolver]. Null outside a signed-in session.
  final DocumentUrlResolver? resolveDocumentUrl;

  /// Structured command/response records per employee id, most recent
  /// last — backs [tasksFor] (the computer popup's "작업 이력" list) and is
  /// capped at [_taskHistoryLimit] entries per employee.
  final Map<String, List<NpcTask>> _tasksByEmployee = {};
  static const _taskHistoryLimit = 20;

  /// Cumulative call/token counters per employee id — backs [usageFor] and
  /// [totalUsage]. Held only in memory; see docs/PHASE6_AI_EMPLOYEES.md for
  /// why this isn't persisted to Supabase (yet).
  final Map<String, NpcUsageSummary> _usageByEmployee = {};

  /// How many past exchanges with an employee are sent as [askEmployee]'s
  /// `history` so it can answer with multi-turn context.
  static const _historyTurnLimit = 6;

  bool _isChatOpen = false;

  Floor _currentFloor = Floor.workspace;
  ComputerInteraction? _nearbyComputer;
  bool _isNearElevator = false;
  bool _isComputerPopupOpen = false;
  bool _isElevatorPopupOpen = false;
  bool _isProfileCardOpen = false;

  static const _minZoom = 0.5;
  static const _maxZoom = 2.5;
  static const _zoomStep = 0.1;
  static const _narrowCanvasWidth = 600.0;
  static const _narrowLobbyZoomFactor = 1.4;
  double _manualZoom = 1;

  /// The floor the player is currently on.
  Floor get currentFloor => _currentFloor;

  /// The current AI employee roster, keyed by workstation.
  List<AiEmployee> get employees => List.unmodifiable(_employees);

  /// The player's current name, role, and presence status.
  PlayerProfile get playerProfile => player.profile;

  /// Whether the computer interaction state is currently open.
  bool get isComputerPopupOpen => _isComputerPopupOpen;

  /// Whether the player is close enough to use a workstation computer.
  bool get isComputerNearby => nearbyEmployee != null;

  /// Whether the player is close enough to use the elevator.
  bool get isElevatorNearby => _isNearElevator;

  /// Whether the elevator's floor-select popup is open.
  bool get isElevatorPopupOpen => _isElevatorPopupOpen;

  /// The AI employee assigned to the computer the player is currently near,
  /// or that the open popup refers to.
  AiEmployee? get nearbyEmployee {
    final workstationId = _nearbyComputer?.workstationId;
    if (workstationId == null) {
      return null;
    }
    return _employeeFor(workstationId);
  }

  /// Opens the computer popup when the player is in interaction range.
  void openComputerPopup() {
    if (isComputerNearby) {
      _setComputerPopupOpen(true);
    }
  }

  /// Closes the computer popup and restores normal game input.
  void closeComputerPopup() => _setComputerPopupOpen(false);

  /// Opens the elevator's floor-select popup when the player is nearby.
  void openElevatorPopup() {
    if (_isNearElevator && !_isComputerPopupOpen && !_isProfileCardOpen) {
      _setElevatorPopupOpen(true);
    }
  }

  /// Closes the elevator popup and restores normal game input.
  void closeElevatorPopup() => _setElevatorPopupOpen(false);

  /// Moves the player to [target] floor, arriving next to that floor's
  /// elevator. A no-op if already on that floor.
  Future<void> changeFloor(Floor target) async {
    if (target == _currentFloor) {
      closeElevatorPopup();
      return;
    }
    world.removeAll(_floorComponents[_currentFloor]!);
    _currentFloor = target;
    final layout = FloorLayouts.forFloor(target);
    player.changeFloorLayout(layout);
    player.position = layout.arrivalPosition.clone();
    elevator.position = layout.elevatorPosition.clone();
    await world.addAll(_floorComponents[target]!);
    _applyResponsiveZoom();
    camera.setBounds(
      Rectangle.fromLTWH(0, 0, layout.worldSize.x, layout.worldSize.y),
      considerViewport: true,
    );
    _onPlayerMoved(player.position);
    _refreshRemotePlayerVisibility();
    _broadcastState(force: true);
    closeElevatorPopup();
    notifyListeners();
  }

  /// Whether the player's profile card is currently open.
  bool get isProfileCardOpen => _isProfileCardOpen;

  /// Opens the player's profile card (avatar preview, name, role, status).
  void openProfileCard() {
    if (_isComputerPopupOpen || _isElevatorPopupOpen) {
      return;
    }
    _isProfileCardOpen = true;
    notifyListeners();
  }

  /// Closes the player's profile card.
  void closeProfileCard() {
    _isProfileCardOpen = false;
    notifyListeners();
  }

  /// Whether the space chat panel is open.
  bool get isChatOpen => _isChatOpen;

  /// The company's shared space chat, oldest first.
  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);

  /// This session's own multiplayer user id, or `'local'` outside a
  /// signed-in session — used by [ChatPanel] to tell whispers meant for
  /// this user apart from ones meant for someone else.
  String get selfUserId => multiplayer?.userId ?? 'local';

  /// Opens the space chat panel, pausing player movement while typing.
  void openChat() {
    if (_isChatOpen) {
      return;
    }
    _isChatOpen = true;
    player.movementEnabled = false;
    notifyListeners();
  }

  /// Closes the space chat panel and restores normal movement.
  void closeChat() {
    if (!_isChatOpen) {
      return;
    }
    _isChatOpen = false;
    player.movementEnabled = true;
    notifyListeners();
  }

  /// Set by [openChatWithEmployee] so [ChatPanel] can open straight into
  /// that employee's room instead of the room list. Consumed (cleared) by
  /// [ChatPanel] once it's read it, so it only applies to the panel open
  /// that follows — later manual chat opens land on the room list as usual.
  String? _pendingChatPeerName;
  String? get pendingChatPeerName => _pendingChatPeerName;
  void consumePendingChatPeer() => _pendingChatPeerName = null;

  /// Closes the computer popup and opens the space chat directly into
  /// [employee]'s private room — the "대화하기" button's target.
  void openChatWithEmployee(AiEmployee employee) {
    closeComputerPopup();
    _pendingChatPeerName = employee.name;
    openChat();
  }

  /// The most recent reply [employee] has sent in chat, or null if none
  /// yet — backs the computer popup's "작업 확인" button.
  ChatMessage? lastReplyFrom(AiEmployee employee) {
    for (final message in _chatMessages.reversed) {
      if (message.isNpc && message.senderName == employee.name) {
        return message;
      }
    }
    return null;
  }

  /// The structured command/response history for [employee], most recent
  /// first — backs the computer popup's "작업 이력" list. Includes
  /// in-flight (`pending`) and failed (`error`) entries, not just
  /// successful replies like [lastReplyFrom].
  List<NpcTask> tasksFor(AiEmployee employee) {
    final tasks = _tasksByEmployee[employee.id] ?? const <NpcTask>[];
    return List.unmodifiable(tasks.reversed);
  }

  /// Cumulative call/success/failure/token counters for [employee] — backs
  /// the computer popup's usage line. Every `askEmployee` attempt counts,
  /// including ones an automatic retry made.
  NpcUsageSummary usageFor(AiEmployee employee) =>
      _usageByEmployee[employee.id] ?? const NpcUsageSummary();

  /// The same counters summed across every employee.
  NpcUsageSummary get totalUsage => _usageByEmployee.values.fold(
        const NpcUsageSummary(),
        (total, summary) => total + summary,
      );

  void _recordUsage(String employeeId, {required bool success, NpcUsage? usage}) {
    final current = _usageByEmployee[employeeId] ?? const NpcUsageSummary();
    _usageByEmployee[employeeId] = NpcUsageSummary(
      calls: current.calls + 1,
      successes: current.successes + (success ? 1 : 0),
      failures: current.failures + (success ? 0 : 1),
      promptTokens: current.promptTokens + (usage?.promptTokens ?? 0),
      completionTokens:
          current.completionTokens + (usage?.completionTokens ?? 0),
    );
    onUsageEvent?.call(employeeId, success: success, usage: usage);
  }

  /// Resolves [task]'s [NpcTask.documentPath] to an openable URL via
  /// [resolveDocumentUrl], or null if it has no document or no resolver is
  /// configured (e.g. tests, no signed-in session).
  Future<String?> documentUrlFor(NpcTask task) {
    final path = task.documentPath;
    final resolver = resolveDocumentUrl;
    if (path == null || resolver == null) {
      return Future.value(null);
    }
    return resolver(path);
  }

  /// The last [_historyTurnLimit] turns already exchanged with [employee],
  /// oldest first, formatted for [NpcCommandHandler]'s `history` parameter.
  List<Map<String, String>> _historyFor(AiEmployee employee) {
    final turns = <Map<String, String>>[];
    for (final message in _chatMessages) {
      if (!message.isNpc && message.toName == employee.name) {
        // Strip the leading `@employee` so history holds just the command
        // text, matching what's passed as askEmployee's `command` argument.
        final content = _parseMention(message.body)?.command ?? message.body;
        turns.add({'role': 'user', 'content': content});
      } else if (message.isNpc && message.senderName == employee.name) {
        turns.add({'role': 'assistant', 'content': message.body});
      }
    }
    if (turns.length <= _historyTurnLimit) {
      return turns;
    }
    return turns.sublist(turns.length - _historyTurnLimit);
  }

  /// Sends [body] as a space chat message: shows it locally right away,
  /// broadcasts it to other signed-in users, and reports it via
  /// [onChatMessageSent] for the host app to persist.
  ///
  /// A leading `@name` addresses the message: both forms are private —
  /// only [ChatPanel]'s 귓속말 tab, not the public 공간 채팅 tab — while a
  /// plain message with no (or no matching) mention is public.
  ///
  /// `@employee 오늘 할 일 정리해줘` sends a command to that AI employee (its
  /// reply is posted as a follow-up message once [askEmployee] resolves);
  /// `@username ...` whispers to that other signed-in user instead.
  void sendChatMessage(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final multiplayer = this.multiplayer;
    final selfId = multiplayer?.userId ?? 'local';
    final mention = _parseMention(trimmed);
    String? toUserId;
    String? toName;
    AiEmployee? employee;
    // Captured before the current message is appended below, so it holds
    // only *prior* turns — the command itself is passed separately to
    // _dispatchNpcCommand and shouldn't also show up inside its own history.
    List<Map<String, String>>? history;
    if (mention != null) {
      final remote = _remoteStateByName(mention.name);
      if (remote != null) {
        toUserId = remote.userId;
        toName = remote.name;
      } else {
        employee = _employeeByName(mention.name);
        if (employee != null) {
          // A command to an NPC is private to me too — only I see the
          // exchange, in ChatPanel's 귓속말 tab, same as a user whisper.
          toUserId = selfId;
          toName = employee.name;
          history = _historyFor(employee);
        }
      }
    }

    final message = ChatMessage(
      id: '${DateTime.now().microsecondsSinceEpoch}-$selfId',
      userId: selfId,
      senderName: player.profile.name,
      body: trimmed,
      createdAt: DateTime.now(),
      toUserId: toUserId,
      toName: toName,
    );
    _chatMessages = [..._chatMessages, message];
    multiplayer?.sendChat(message);
    onChatMessageSent?.call(message);
    notifyListeners();

    if (employee != null && mention!.command.isNotEmpty) {
      unawaited(_dispatchNpcCommand(
        employee: employee,
        command: mention.command,
        history: history ?? const [],
      ));
    }
  }

  /// A leading `@name`, split from the rest of the message. `command` is
  /// empty when there's nothing after the mention (e.g. just `@하나`).
  ({String name, String command})? _parseMention(String body) {
    if (!body.startsWith('@')) {
      return null;
    }
    final spaceIndex = body.indexOf(' ');
    final name =
        spaceIndex == -1 ? body.substring(1) : body.substring(1, spaceIndex);
    if (name.isEmpty) {
      return null;
    }
    final command =
        spaceIndex == -1 ? '' : body.substring(spaceIndex + 1).trim();
    return (name: name, command: command);
  }

  AiEmployee? _employeeByName(String name) {
    for (final employee in _employees) {
      if (employee.name.toLowerCase() == name.toLowerCase()) {
        return employee;
      }
    }
    return null;
  }

  RemotePlayerState? _remoteStateByName(String name) {
    for (final component in _remotePlayers.values) {
      if (component.state.name.toLowerCase() == name.toLowerCase()) {
        return component.state;
      }
    }
    return null;
  }

  /// Asks [employee] to respond to [command] via [askEmployee] (retrying
  /// once on failure), records the exchange as an [NpcTask], then posts the
  /// reply as a normal (non-whispered) chat message from that employee.
  Future<void> _dispatchNpcCommand({
    required AiEmployee employee,
    required String command,
    required List<Map<String, String>> history,
  }) async {
    final askEmployee = this.askEmployee;
    final taskId = '${DateTime.now().microsecondsSinceEpoch}-task-${employee.id}';
    _recordTask(NpcTask(
      id: taskId,
      employeeId: employee.id,
      command: command,
      status: NpcTaskStatus.pending,
      createdAt: DateTime.now(),
    ));

    String replyBody;
    if (askEmployee == null) {
      replyBody = 'AI 연동이 아직 설정되지 않았습니다. docs/PHASE6_AI_EMPLOYEES.md를 참고해주세요.';
      _updateTask(
        employee.id,
        taskId,
        (task) => task.copyWith(
          status: NpcTaskStatus.error,
          errorMessage: replyBody,
        ),
      );
    } else {
      // Flip to "작업 중" for the round trip so the NPC visibly looks busy,
      // then back to whatever it was before (or "오류" on failure) —
      // ephemeral, not persisted via onEmployeeChanged, since this fires on
      // every chat command and isn't a roster edit an admin made.
      final previousStatus = employee.status;
      _setEmployeeStatus(employee, NpcStatus.working);

      // One automatic retry: a single dropped connection or transient
      // OpenAI hiccup shouldn't immediately show the employee as errored.
      const maxAttempts = 2;
      Object? lastError;
      NpcCommandResult? result;
      var attemptsUsed = 0;
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        attemptsUsed = attempt;
        try {
          result = await askEmployee(
            employeeName: employee.name,
            employeeRole: employee.role,
            command: command,
            history: history,
          );
          _recordUsage(employee.id, success: true, usage: result.usage);
          lastError = null;
          break;
        } catch (e) {
          _recordUsage(employee.id, success: false);
          lastError = e;
        }
      }

      if (lastError == null) {
        replyBody = result!.reply;
        _setEmployeeStatus(employee, previousStatus);
        _updateTask(
          employee.id,
          taskId,
          (task) => task.copyWith(
            status: NpcTaskStatus.success,
            result: replyBody,
            attempts: attemptsUsed,
            usage: result!.usage,
          ),
        );

        // Turns the reply into an actual saved work product — the "실제
        // 업무 수행" a chat message alone doesn't convey — best-effort so a
        // storage hiccup never blocks the chat reply itself.
        final generateDocument = this.generateDocument;
        if (generateDocument != null) {
          try {
            final documentPath = await generateDocument(
              employeeId: employee.id,
              employeeName: employee.name,
              taskId: taskId,
              command: command,
              result: replyBody,
            );
            if (documentPath != null) {
              _updateTask(
                employee.id,
                taskId,
                (task) => task.copyWith(documentPath: documentPath),
              );
            }
          } catch (_) {
            // No document this time; the chat reply above already landed.
          }
        }
      } else {
        replyBody = '응답을 가져오지 못했습니다 (재시도 후에도 실패): $lastError';
        _setEmployeeStatus(employee, NpcStatus.error);
        _updateTask(
          employee.id,
          taskId,
          (task) => task.copyWith(
            status: NpcTaskStatus.error,
            errorMessage: '$lastError',
            attempts: maxAttempts,
          ),
        );
      }
    }

    final multiplayer = this.multiplayer;
    final selfId = multiplayer?.userId ?? 'local';
    final reply = ChatMessage(
      id: '${DateTime.now().microsecondsSinceEpoch}-npc-${employee.id}',
      userId: selfId,
      senderName: employee.name,
      body: replyBody,
      createdAt: DateTime.now(),
      // Private to me, like the command that triggered it — see
      // sendChatMessage's mention handling.
      toUserId: selfId,
      isNpc: true,
    );
    _chatMessages = [..._chatMessages, reply];
    multiplayer?.sendChat(reply);
    onChatMessageSent?.call(reply);
    notifyListeners();
  }

  /// Appends [task] to its employee's history, trimming to
  /// [_taskHistoryLimit] entries.
  void _recordTask(NpcTask task) {
    final tasks = _tasksByEmployee.putIfAbsent(task.employeeId, () => []);
    tasks.add(task);
    if (tasks.length > _taskHistoryLimit) {
      tasks.removeAt(0);
    }
    onTaskChanged?.call(task);
  }

  /// Replaces the task identified by [employeeId]/[taskId] with the result
  /// of [update], if it's still present (it always should be — tasks are
  /// only trimmed from the opposite end once far more than [_taskHistoryLimit]
  /// commands have been sent to the same employee).
  void _updateTask(
    String employeeId,
    String taskId,
    NpcTask Function(NpcTask) update,
  ) {
    final tasks = _tasksByEmployee[employeeId];
    if (tasks == null) {
      return;
    }
    final index = tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return;
    }
    final updated = update(tasks[index]);
    tasks[index] = updated;
    onTaskChanged?.call(updated);
  }

  /// Applies edited roster data for one AI employee (name, role, status).
  /// Intended for use by an owner/HR-manager admin panel.
  void updateEmployee(AiEmployee updated) {
    final index = _employees.indexWhere((e) => e.id == updated.id);
    if (index == -1) {
      return;
    }
    _employees[index] = updated;
    _npcsByWorkstation[updated.workstationId]?.updateEmployee(updated);
    onEmployeeChanged?.call(updated);
    notifyListeners();
  }

  /// Updates just [employee]'s status badge — in memory and on its NPC
  /// sprite — without calling [onEmployeeChanged]. Used to flash "작업 중"
  /// while an `@employee` chat command is in flight; a real roster edit
  /// should go through [updateEmployee] instead so it gets persisted.
  void _setEmployeeStatus(AiEmployee employee, NpcStatus status) {
    final index = _employees.indexWhere((e) => e.id == employee.id);
    if (index == -1) {
      return;
    }
    final updated = _employees[index].copyWith(status: status);
    _employees[index] = updated;
    _npcsByWorkstation[updated.workstationId]?.updateEmployee(updated);
    notifyListeners();
  }

  /// Applies an edited player profile (name, role, status). Intended for use
  /// by an owner/HR-manager admin panel.
  void updatePlayerProfile(PlayerProfile updated) {
    player.updateProfile(updated);
    _broadcastState(force: true);
    notifyListeners();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    camera.backdrop = ExteriorBackdrop();
    await world.addAll(
      [elevator, player, ..._floorComponents[_currentFloor]!],
    );
    final layout = FloorLayouts.forFloor(_currentFloor);
    camera.setBounds(
      Rectangle.fromLTWH(0, 0, layout.worldSize.x, layout.worldSize.y),
      considerViewport: true,
    );
    camera.follow(player, snap: true);

    final multiplayer = this.multiplayer;
    if (multiplayer != null) {
      await multiplayer.connect(
        initial: _buildLocalState(multiplayer.userId),
        onChanged: _onRemoteStatesChanged,
        onChatMessage: _onRemoteChatMessage,
      );
    }
  }

  void _onRemoteChatMessage(ChatMessage message) {
    _chatMessages = [..._chatMessages, message];
    notifyListeners();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _applyResponsiveZoom();
  }

  double get _responsiveZoomFactor => _currentFloor == Floor.lobby &&
          hasLayout &&
          canvasSize.x < _narrowCanvasWidth
      ? _narrowLobbyZoomFactor
      : 1;

  void _applyResponsiveZoom() {
    camera.viewfinder.zoom =
        (_manualZoom * _responsiveZoomFactor).clamp(_minZoom, _maxZoom);
  }

  @override
  void onScroll(PointerScrollInfo info) {
    final direction = info.scrollDelta.global.y.sign;
    final zoom = camera.viewfinder.zoom - direction * _zoomStep;
    camera.viewfinder.zoom = zoom.clamp(_minZoom, _maxZoom);
    // Store the user adjustment separately so resizing or a floor change
    // removes only the automatic narrow-lobby magnification.
    _manualZoom = (camera.viewfinder.zoom / _responsiveZoomFactor)
        .clamp(_minZoom, _maxZoom);
  }

  /// Applies the computer/elevator interaction keys without creating
  /// presentation UI.
  void handleInteractionKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.keyE) {
      if (isComputerNearby) {
        openComputerPopup();
      } else if (_isNearElevator) {
        openElevatorPopup();
      }
    } else if (key == LogicalKeyboardKey.escape) {
      if (_isComputerPopupOpen) {
        closeComputerPopup();
      }
      if (_isElevatorPopupOpen) {
        closeElevatorPopup();
      }
      if (_isProfileCardOpen) {
        closeProfileCard();
      }
      if (_isChatOpen) {
        closeChat();
      }
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      // Only opens here — while chat is already open, Enter is the
      // ChatPanel TextField's own submit key (send if there's text, or
      // close on an empty submit; see ChatPanel._send), which the focused
      // TextField handles directly rather than this game-level shortcut.
      if (!_isChatOpen) {
        openChat();
      }
    }
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (event is KeyDownEvent) {
      handleInteractionKey(event.logicalKey);
    }
    return super.onKeyEvent(event, keysPressed);
  }

  /// Null when [workstationId] has no assigned employee yet — e.g. a
  /// workstation just added to the map before every existing company's
  /// roster has caught up with a matching seat.
  AiEmployee? _employeeFor(String workstationId) {
    for (final employee in _employees) {
      if (employee.workstationId == workstationId) {
        return employee;
      }
    }
    return null;
  }

  void _onPlayerMoved(Vector2 position) {
    if (_currentFloor == Floor.workspace) {
      _updateComputerProximity(position);
    } else if (_nearbyComputer != null) {
      _nearbyComputer = null;
      notifyListeners();
    }
    _updateElevatorProximity(position);
    _updateRenderPriorities();
    _broadcastState();
  }

  void _updateRenderPriorities() {
    if (_currentFloor == Floor.lobby) {
      player.setRenderPriority(IsoProjection.priorityFor(player.position));
      elevator.priority = IsoProjection.priorityFor(elevator.position);
      for (final npc
          in _floorComponents[Floor.lobby]!.whereType<NpcComponent>()) {
        npc.setRenderPriority(IsoProjection.priorityFor(npc.position));
      }
      return;
    }

    player.setRenderPriority(_playerPriority);
    elevator.priority = _furniturePriority;
  }

  RemotePlayerState _buildLocalState(String userId) {
    final profile = player.profile;
    return RemotePlayerState(
      userId: userId,
      name: profile.name,
      role: profile.role,
      statusLabel: profile.status.displayLabel,
      statusColorValue: profile.status.displayColor.toARGB32(),
      floorLevel: _currentFloor.level,
      x: player.position.x,
      y: player.position.y,
    );
  }

  void _broadcastState({bool force = false}) {
    final multiplayer = this.multiplayer;
    if (multiplayer == null) {
      return;
    }
    multiplayer.updateState(_buildLocalState(multiplayer.userId), force: force);
  }

  void _onRemoteStatesChanged(Map<String, RemotePlayerState> states) {
    final disconnectedIds =
        _remotePlayers.keys.where((id) => !states.containsKey(id)).toList();
    for (final id in disconnectedIds) {
      _remotePlayers.remove(id)?.removeFromParent();
    }

    for (final state in states.values) {
      var component = _remotePlayers[state.userId];
      if (component == null) {
        component = RemotePlayerComponent(state: state)
          ..priority = _playerPriority;
        _remotePlayers[state.userId] = component;
      } else {
        component.applyState(state);
      }
      _updateRemotePlayerPriority(component);
      final sameFloor = state.floorLevel == _currentFloor.level;
      if (sameFloor && !component.isMounted) {
        world.add(component);
      } else if (!sameFloor && component.isMounted) {
        component.removeFromParent();
      }
    }
  }

  void _refreshRemotePlayerVisibility() {
    for (final component in _remotePlayers.values) {
      _updateRemotePlayerPriority(component);
      final sameFloor = component.floorLevel == _currentFloor.level;
      if (sameFloor && !component.isMounted) {
        world.add(component);
      } else if (!sameFloor && component.isMounted) {
        component.removeFromParent();
      }
    }
  }

  void _updateRemotePlayerPriority(RemotePlayerComponent component) {
    component.priority = _currentFloor == Floor.lobby
        ? IsoProjection.priorityFor(component.position)
        : _playerPriority;
  }

  void _updateComputerProximity(Vector2 playerPosition) {
    ComputerInteraction? nearby;
    for (final computer in computers) {
      if (computer.isPlayerNearby(playerPosition)) {
        nearby = computer;
        break;
      }
    }
    if (_nearbyComputer == nearby) {
      return;
    }
    _nearbyComputer = nearby;
    notifyListeners();
  }

  void _updateElevatorProximity(Vector2 playerPosition) {
    final nearby = elevator.isPlayerNearby(playerPosition);
    if (_isNearElevator == nearby) {
      return;
    }
    _isNearElevator = nearby;
    notifyListeners();
  }

  void _setPlayerHovered(bool hovered) {
    mouseCursor = hovered ? SystemMouseCursors.click : MouseCursor.defer;
  }

  void _setComputerPopupOpen(bool value) {
    if (_isComputerPopupOpen == value) {
      return;
    }
    _isComputerPopupOpen = value;
    player.movementEnabled = !value;
    notifyListeners();
  }

  void _setElevatorPopupOpen(bool value) {
    if (_isElevatorPopupOpen == value) {
      return;
    }
    _isElevatorPopupOpen = value;
    player.movementEnabled = !value;
    notifyListeners();
  }

  List<ComputerInteraction> _buildComputers() {
    return Workstation.all
        .map((workstation) => ComputerInteraction(
              position: workstation.computerPosition,
              workstationId: workstation.id,
            ))
        .toList();
  }

  /// NPCs for the 2층 desk grid — only employees whose `workstationId`
  /// matches one of those desks. Employees seated elsewhere (see
  /// [_buildFloorNpcs]) are skipped rather than crashing on a missing
  /// lookup.
  List<NpcComponent> _buildNpcs() {
    final workstationsById = {for (final w in Workstation.all) w.id: w};
    return _employees
        .where(
            (employee) => workstationsById.containsKey(employee.workstationId))
        .map((employee) {
      final npc = NpcComponent(
        employee: employee,
        position: workstationsById[employee.workstationId]!.seatPosition,
      );
      _npcsByWorkstation[employee.workstationId] = npc;
      return npc;
    }).toList();
  }

  /// NPCs seated on [floor] per [NpcPlacement] — 3층/4층's own furniture
  /// layout, distinct from the repeating 2층 desk grid [_buildNpcs] uses.
  List<NpcComponent> _buildFloorNpcs(Floor floor) {
    final placementsById = {
      for (final p in NpcPlacement.forFloor(floor)) p.id: p,
    };
    return _employees
        .where((employee) => placementsById.containsKey(employee.workstationId))
        .map((employee) {
      final npc = NpcComponent(
        employee: employee,
        position: placementsById[employee.workstationId]!.position,
      );
      _npcsByWorkstation[employee.workstationId] = npc;
      return npc;
    }).toList();
  }
}
