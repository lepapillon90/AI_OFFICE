import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// The elevator: sits at the same coordinates on every floor and lets the
/// player switch floors when nearby. Renders itself since it isn't part of
/// any single floor's furniture set.
class ElevatorInteraction extends PositionComponent {
  ElevatorInteraction({required super.position})
      : super(anchor: Anchor.center, size: Vector2.all(56));

  static const interactionRadius = 72.0;

  bool isPlayerNearby(Vector2 playerPosition) =>
      position.distanceTo(playerPosition) <= interactionRadius;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    await addAll([
      RectangleComponent(
        size: size.clone(),
        paint: Paint()..color = const Color(0xFF90A4AE),
      ),
      RectangleComponent(
        size: Vector2(size.x - 8, size.y - 8),
        position: Vector2(4, 4),
        paint: Paint()..color = const Color(0xFF37474F),
      ),
      TextComponent(
        text: '엘리베이터',
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
