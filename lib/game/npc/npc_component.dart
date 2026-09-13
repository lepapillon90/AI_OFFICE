import 'package:ai_office/game/map/office_layout.dart';
import 'package:ai_office/game/npc/ai_employee.dart';
import 'package:ai_office/game/npc/npc_status.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Renders a stationary AI employee NPC with a status label above its head.
class NpcComponent extends PositionComponent {
  NpcComponent({
    required this.employee,
    required Vector2 position,
  }) : super(
          position: position,
          size: OfficeLayout.characterSize.clone(),
          anchor: Anchor.center,
        );

  final AiEmployee employee;

  late final SpriteComponent _sprite;
  late final TextComponent _statusLabel;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _sprite = SpriteComponent(
      sprite: await Sprite.load(
        'characters/office_worker.png',
        srcSize: Vector2.all(64),
      ),
      size: size.clone(),
    );

    _statusLabel = TextComponent(
      text: employee.displayStatus,
      anchor: Anchor.bottomCenter,
      position: Vector2(size.x / 2, -4),
      textRenderer: TextPaint(
        style: TextStyle(
          color: employee.status.displayColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black54,
        ),
      ),
    );

    await addAll([_sprite, _statusLabel]);
  }
}
