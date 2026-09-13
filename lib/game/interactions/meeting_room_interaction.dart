import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// The meeting room table (2F, inside the meeting-room partition — see
/// OfficeLayout.blockers): lets the player start/track/end a meeting when
/// nearby. Renders itself like ElevatorInteraction, since it isn't part of
/// OfficeMap's furniture set.
class MeetingRoomInteraction extends PositionComponent {
  MeetingRoomInteraction({required super.position})
      : super(anchor: Anchor.center, size: Vector2(96, 56));

  static const interactionRadius = 80.0;

  bool isPlayerNearby(Vector2 playerPosition) =>
      position.distanceTo(playerPosition) <= interactionRadius;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    await addAll([
      RectangleComponent(
        size: size.clone(),
        paint: Paint()..color = const Color(0xFF8D6E63),
      ),
      RectangleComponent(
        size: Vector2(size.x - 8, size.y - 8),
        position: Vector2(4, 4),
        paint: Paint()..color = const Color(0xFF6D4C41),
      ),
      TextComponent(
        text: '회의실',
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
}
