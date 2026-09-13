import 'package:ai_office/game/interactions/computer_interaction.dart';
import 'package:ai_office/game/map/office_layout.dart';
import 'package:ai_office/game/map/office_map.dart';
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
    computerInteraction = ComputerInteraction(position: Vector2(400, 350));
    player = OfficePlayer(
      position: playerPosition,
      onPositionChanged: _updateComputerProximity,
    );
    _updateComputerProximity(player.position);
  }

  late final OfficePlayer player;
  late final ComputerInteraction computerInteraction;
  bool _isPlayerNearComputer = false;
  bool _isComputerPopupOpen = false;

  static const _minZoom = 0.5;
  static const _maxZoom = 2.5;
  static const _zoomStep = 0.1;

  /// Whether the computer interaction state is currently open.
  bool get isComputerPopupOpen => _isComputerPopupOpen;

  /// Whether the player is close enough to use the computer.
  bool get isComputerNearby => _isPlayerNearComputer;

  /// Opens the computer popup when the player is in interaction range.
  void openComputerPopup() {
    if (_isPlayerNearComputer) {
      _setComputerPopupOpen(true);
    }
  }

  /// Closes the computer popup and restores normal game input.
  void closeComputerPopup() => _setComputerPopupOpen(false);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    await world.addAll(
      [OfficeMap(), computerInteraction, player, ..._buildNpcs()],
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
    if (key == LogicalKeyboardKey.keyE && _isPlayerNearComputer) {
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
    final isNearby = computerInteraction.isPlayerNearby(playerPosition);
    if (_isPlayerNearComputer == isNearby) {
      return;
    }
    _isPlayerNearComputer = isNearby;
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
