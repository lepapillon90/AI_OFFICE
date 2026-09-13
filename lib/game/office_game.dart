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
typedef NpcCommandHandler = Future<String> Function({
  required String employeeName,
  required String employeeRole,
  required String command,
});

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
  }) : this._(
          playerPosition: OfficeLayout.worldSize.clone() / 2,
          employees: employees,
          onEmployeeChanged: onEmployeeChanged,
          multiplayer: multiplayer,
          initialChatMessages: initialChatMessages,
          onChatMessageSent: onChatMessageSent,
          askEmployee: askEmployee,
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
  }) {
    _chatMessages = List.of(initialChatMessages ?? const []);
    _employees = List.of(employees ?? sampleEmployees);
    computers = _buildComputers()..forEach((c) => c.priority = _furniturePriority);
    elevator = ElevatorInteraction(position: FloorLayouts.elevatorPosition)
      ..priority = _furniturePriority;
    player = OfficePlayer(
      position: playerPosition,
      onPositionChanged: _onPlayerMoved,
      onHoverChanged: _setPlayerHovered,
      onTap: openProfileCard,
    )..priority = _playerPriority;
    final npcs = _buildNpcs()..forEach((npc) => npc.priority = _npcPriority);
    _floorComponents = {
      Floor.lobby: IsoLobbyScene().createComponents(),
      Floor.workspace: [OfficeMap(), ...computers, ...npcs],
      Floor.projectRoom: [ProjectRoomMap()],
      Floor.executive: [ExecutiveMap()],
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
      unawaited(_dispatchNpcCommand(employee: employee, command: mention.command));
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

  /// Asks [employee] to respond to [command] via [askEmployee], then posts
  /// the reply as a normal (non-whispered) chat message from that employee.
  Future<void> _dispatchNpcCommand({
    required AiEmployee employee,
    required String command,
  }) async {
    final askEmployee = this.askEmployee;
    final replyBody = askEmployee == null
        ? 'AI 연동이 아직 설정되지 않았습니다. docs/PHASE6_AI_EMPLOYEES.md를 참고해주세요.'
        : await askEmployee(
            employeeName: employee.name,
            employeeRole: employee.role,
            command: command,
          ).catchError((Object e) => '응답을 가져오지 못했습니다: $e');

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
  void onScroll(PointerScrollInfo info) {
    final direction = info.scrollDelta.global.y.sign;
    final zoom = camera.viewfinder.zoom - direction * _zoomStep;
    camera.viewfinder.zoom = zoom.clamp(_minZoom, _maxZoom);
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
      final sameFloor = component.floorLevel == _currentFloor.level;
      if (sameFloor && !component.isMounted) {
        world.add(component);
      } else if (!sameFloor && component.isMounted) {
        component.removeFromParent();
      }
    }
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

  List<NpcComponent> _buildNpcs() {
    final workstationsById = {for (final w in Workstation.all) w.id: w};
    return _employees.map((employee) {
      final npc = NpcComponent(
        employee: employee,
        position: workstationsById[employee.workstationId]!.seatPosition,
      );
      _npcsByWorkstation[employee.workstationId] = npc;
      return npc;
    }).toList();
  }
}
