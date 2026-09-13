import 'package:ai_office/game/npc/ai_employee.dart';
import 'package:flame/components.dart';

/// Defines the area in which a player can interact with a workstation
/// computer, and the AI employee assigned to that computer.
class ComputerInteraction extends PositionComponent {
  ComputerInteraction({required super.position, required this.employee})
      : super(anchor: Anchor.center);

  static const interactionRadius = 72.0;

  final AiEmployee employee;

  /// Whether [playerPosition] lies within this computer's interaction area.
  bool isPlayerNearby(Vector2 playerPosition) =>
      position.distanceTo(playerPosition) <= interactionRadius;
}
