import 'package:ai_office/game/exterior_backdrop.dart';
import 'package:ai_office/game/floors/executive_map.dart';
import 'package:ai_office/game/floors/floor.dart';
import 'package:ai_office/game/floors/floor_layout.dart';
import 'package:ai_office/game/floors/lobby_map.dart';
import 'package:ai_office/game/floors/project_room_map.dart';
import 'package:ai_office/game/interactions/computer_interaction.dart';
import 'package:ai_office/game/interactions/elevator_interaction.dart';
import 'package:ai_office/game/map/office_layout.dart';
import 'package:ai_office/game/map/office_map.dart';
import 'package:ai_office/game/npc/ai_employee.dart';
import 'package:ai_office/game/npc/npc_component.dart';
import 'package:ai_office/game/npc/sample_employees.dart';
import 'package:ai_office/game/npc/workstation.dart';
import 'package:ai_office/game/player/office_player.dart';
import 'package:ai_office/game/player/player_profile.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The interactive office world and its camera configuration.
class OfficeGame extends FlameGame
    with HasKeyboardHandlerComponents, ScrollDetector, ChangeNotifier {
  OfficeGame({
    List<AiEmployee>? employees,
    void Function(AiEmployee)? onEmployeeChanged,
  }) : this._(
          playerPosition: OfficeLayout.worldSize.clone() / 2,
          employees: employees,
          onEmployeeChanged: onEmployeeChanged,
        );

  OfficeGame.forTest({required Vector2 playerPosition})
      : this._(playerPosition: playerPosition);

  OfficeGame._({
    required Vector2 playerPosition,
    List<AiEmployee>? employees,
    this.onEmployeeChanged,
  }) {
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
      Floor.lobby: [LobbyMap()],
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
  final Map<String, NpcComponent> _npcsByWorkstation = {};
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
  bool get isComputerNearby => _nearbyComputer != null;

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
    if (_nearbyComputer != null) {
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
    await world.addAll(_floorComponents[target]!);
    camera.setBounds(
      Rectangle.fromLTWH(0, 0, layout.worldSize.x, layout.worldSize.y),
      considerViewport: true,
    );
    _onPlayerMoved(player.position);
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
      if (_nearbyComputer != null) {
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

  AiEmployee _employeeFor(String workstationId) =>
      _employees.firstWhere((e) => e.workstationId == workstationId);

  void _onPlayerMoved(Vector2 position) {
    if (_currentFloor == Floor.workspace) {
      _updateComputerProximity(position);
    } else if (_nearbyComputer != null) {
      _nearbyComputer = null;
      notifyListeners();
    }
    _updateElevatorProximity(position);
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
