import 'package:ai_office/game/interactions/computer_interaction.dart';
import 'package:ai_office/game/map/office_layout.dart';
import 'package:ai_office/game/map/office_map.dart';
import 'package:ai_office/game/npc/ai_employee.dart';
import 'package:ai_office/game/npc/npc_component.dart';
import 'package:ai_office/game/npc/sample_employees.dart';
import 'package:ai_office/game/npc/workstation.dart';
import 'package:ai_office/game/player/office_player.dart';
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
    computers = _buildComputers();
    player = OfficePlayer(
      position: playerPosition,
      onPositionChanged: _updateComputerProximity,
    );
    _updateComputerProximity(player.position);
  }

  late final OfficePlayer player;
  late final List<ComputerInteraction> computers;
  ComputerInteraction? _nearbyComputer;
  bool _isComputerPopupOpen = false;

  static const _minZoom = 0.5;
  static const _maxZoom = 2.5;
  static const _zoomStep = 0.1;

  /// Whether the computer interaction state is currently open.
  bool get isComputerPopupOpen => _isComputerPopupOpen;

  /// Whether the player is close enough to use a workstation computer.
  bool get isComputerNearby => _nearbyComputer != null;

  /// The AI employee assigned to the computer the player is currently near,
  /// or that the open popup refers to.
  AiEmployee? get nearbyEmployee => _nearbyComputer?.employee;

  /// Opens the computer popup when the player is in interaction range.
  void openComputerPopup() {
    if (_nearbyComputer != null) {
      _setComputerPopupOpen(true);
    }
  }

  /// Closes the computer popup and restores normal game input.
  void closeComputerPopup() => _setComputerPopupOpen(false);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    await world.addAll(
      [OfficeMap(), ...computers, player, ..._buildNpcs()],
    );
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

  void _setComputerPopupOpen(bool value) {
    if (_isComputerPopupOpen == value) {
      return;
    }
    _isComputerPopupOpen = value;
    player.movementEnabled = !value;
    notifyListeners();
  }

  List<ComputerInteraction> _buildComputers() {
    final employeesByWorkstation = {
      for (final employee in sampleEmployees) employee.workstationId: employee,
    };
    return Workstation.all
        .map((workstation) => ComputerInteraction(
              position: workstation.computerPosition,
              employee: employeesByWorkstation[workstation.id]!,
            ))
        .toList();
  }

  List<NpcComponent> _buildNpcs() {
    final workstationsById = {for (final w in Workstation.all) w.id: w};
    return sampleEmployees
        .map((employee) => NpcComponent(
              employee: employee,
              position: workstationsById[employee.workstationId]!
                  .seatPosition,
            ))
        .toList();
  }
}
