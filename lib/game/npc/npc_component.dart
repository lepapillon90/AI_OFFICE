import 'package:ai_office/game/map/office_layout.dart';
import 'package:ai_office/game/name_tag_component.dart';
import 'package:ai_office/game/npc/ai_employee.dart';
import 'package:ai_office/game/npc/npc_status.dart';
import 'package:flame/components.dart';

/// Renders a stationary AI employee NPC with a badge, name, and role tag
/// above its head.
class NpcComponent extends PositionComponent {
  NpcComponent({
    required AiEmployee employee,
    required Vector2 position,
  })  : _employee = employee,
        super(
          position: position,
          size: OfficeLayout.characterSize.clone(),
          anchor: Anchor.center,
        );

  AiEmployee _employee;

  /// The AI employee currently assigned to this NPC.
  AiEmployee get employee => _employee;

  void setRenderPriority(int value) => priority = value;

  late final SpriteComponent _sprite;
  late final NameTagComponent _nameTag;

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

    _nameTag = NameTagComponent(
      badgeLabel: _employee.displayStatus,
      badgeColor: _employee.status.displayColor,
      name: _employee.name,
      role: _employee.role,
      characterWidth: size.x,
    );

    await addAll([_sprite, _nameTag]);
  }

  /// Applies edited employee data (name, role, status) to this NPC.
  void updateEmployee(AiEmployee updated) {
    _employee = updated;
    _nameTag.applyChanges(
      badgeLabel: updated.displayStatus,
      badgeColor: updated.status.displayColor,
      name: updated.name,
      role: updated.role,
    );
  }
}
