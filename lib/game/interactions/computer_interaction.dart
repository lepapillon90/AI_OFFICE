import 'package:flame/components.dart';

/// Defines the area in which a player can interact with a workstation
/// computer, identified by the workstation it belongs to.
class ComputerInteraction extends PositionComponent {
  ComputerInteraction({required super.position, required this.workstationId})
      : super(anchor: Anchor.center);

  static const interactionRadius = 72.0;

  final String workstationId;

  /// Whether [playerPosition] lies within this computer's interaction area.
  bool isPlayerNearby(Vector2 playerPosition) =>
      position.distanceTo(playerPosition) <= interactionRadius;
}
