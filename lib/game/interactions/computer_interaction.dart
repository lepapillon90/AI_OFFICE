import 'package:flame/components.dart';

/// Defines the area in which a player can interact with a computer.
class ComputerInteraction extends PositionComponent {
  ComputerInteraction({required super.position}) : super(anchor: Anchor.center);

  static const interactionRadius = 72.0;

  /// Whether [playerPosition] lies within this computer's interaction area.
  bool isPlayerNearby(Vector2 playerPosition) =>
      position.distanceTo(playerPosition) <= interactionRadius;
}
