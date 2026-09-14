import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

/// A clickable "server machine" prop (2F) that opens a password prompt —
/// see [OfficeGame.openServerLockDialog]/[OfficeGame.submitServerPassword]
/// and docs/PHASE8_REMOTE_AGENT.md. This is a game-world flavor gate on
/// `@서버` remote commands specifically (an employee's own linked computer
/// is governed purely by that employee's opt-in checkbox, unaffected by
/// this lock) — the real security boundary is still the command
/// whitelist and per-employee opt-in, not this password.
///
/// Unlike [ComputerInteraction]/[MeetingRoomInteraction] (proximity + the
/// E key), this responds to a direct click/tap, matching how the player's
/// own sprite is interacted with (see OfficePlayer's TapCallbacks).
class ServerMachineInteraction extends PositionComponent with TapCallbacks {
  ServerMachineInteraction({required super.position, this.onTap})
      : super(anchor: Anchor.center, size: Vector2(64, 64));

  final VoidCallback? onTap;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await addAll([
      RectangleComponent(
        size: size.clone(),
        paint: Paint()..color = const Color(0xFF37474F),
      ),
      RectangleComponent(
        size: Vector2(size.x - 8, size.y - 16),
        position: Vector2(4, 4),
        paint: Paint()..color = const Color(0xFF263238),
      ),
      CircleComponent(
        radius: 4,
        position: Vector2(size.x / 2 - 4, size.y - 10),
        paint: Paint()..color = const Color(0xFF00E676),
      ),
      TextComponent(
        text: '서버',
        anchor: Anchor.bottomCenter,
        position: Vector2(size.x / 2, -4),
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'NotoSansKR',
            fontSize: 11,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.black54,
          ),
        ),
      ),
    ]);
  }

  @override
  void onTapDown(TapDownEvent event) => onTap?.call();
}
