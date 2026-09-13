import 'package:ai_office/game/interactions/computer_interaction.dart';
import 'package:ai_office/game/map/office_layout.dart';
import 'package:ai_office/game/map/office_map.dart';
import 'package:ai_office/game/npc/ai_employee.dart';
import 'package:ai_office/game/npc/npc_component.dart';
import 'package:ai_office/game/npc/sample_employees.dart';
import 'package:ai_office/game/npc/workstation.dart';
import 'package:ai_office/game/player/office_player.dart';
import 'package:ai_office/game/player/player_profile.dart';
import 'package:flame/events.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The interactive office world and its camera configuration.
class OfficeGame extends FlameGame
    with HasKeyboardHandlerComponents, ScrollDetector, ChangeNotifier {
  OfficeGame() : this._(playerPosition: OfficeLayout.worldSize.clone() / 2);

  OfficeGame.forTest({required Vector2 playerPosition})
      : this._(playerPosition: playerPosition);

  OfficeGame._({required Vector2 playerPosition}) {
    _employees = List.of(sampleEmployees);
    computers = _buildComputers();
    player = OfficePlayer(
      position: playerPosition,
      onPositionChanged: _updateComputerProximity,
      onHoverChanged: _setPlayerHovered,
      onTap: openProfileCard,
    );
    _updateComputerProximity(player.position);
  }

  late final OfficePlayer player;
  late final List<ComputerInteraction> computers;
  late List<AiEmployee> _employees;
  final Map<String, NpcComponent> _npcsByWorkstation = {};
  ComputerInteraction? _nearbyComputer;
  bool _isComputerPopupOpen = false;
  bool _isProfileCardOpen = false;

  static const _minZoom = 0.5;
  static const _maxZoom = 2.5;
  static const _zoomStep = 0.1;

  /// The current AI employee roster, keyed by workstation.
  List<AiEmployee> get employees => List.unmodifiable(_employees);

  /// The player's current name, role, and presence status.
  PlayerProfile get playerProfile => player.profile;

  /// Whether the computer interaction state is currently open.
  bool get isComputerPopupOpen => _isComputerPopupOpen;

  /// Whether the player is close enough to use a workstation computer.
  bool get isComputerNearby => _nearbyComputer != null;

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

  /// Whether the player's profile card is currently open.
  bool get isProfileCardOpen => _isProfileCardOpen;

  /// Opens the player's profile card (avatar preview, name, role, status).
  void openProfileCard() {
    if (_isComputerPopupOpen) {
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

    final npcs = _buildNpcs();
    await world.addAll([OfficeMap(), ...computers, player, ...npcs]);
    camera.setBounds(
      Rectangle.fromLTWH(
        0,
        0,
        OfficeLayout.worldSize.x,
        OfficeLayout.worldSize.y,
      ),
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

  /// Applies the computer interaction keys without creating presentation UI.
  void handleInteractionKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.keyE && _nearbyComputer != null) {
      openComputerPopup();
    } else if (key == LogicalKeyboardKey.escape && _isComputerPopupOpen) {
      closeComputerPopup();
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
