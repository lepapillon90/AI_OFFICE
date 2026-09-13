import 'dart:ui';

import 'package:ai_office/game/floors/floor.dart';
import 'package:ai_office/game/map/office_layout.dart';
import 'package:flame/components.dart';

/// World size, collision rectangles, and elevator placement for one floor.
///
/// The elevator sits at the same coordinates on every floor, so arriving on
/// a new floor always places the player right next to it.
class FloorLayout {
  const FloorLayout({
    required this.worldSize,
    required this.blockers,
    required this.elevatorPosition,
  });

  final Vector2 worldSize;
  final List<Rect> blockers;
  final Vector2 elevatorPosition;

  Vector2 get arrivalPosition =>
      Vector2(elevatorPosition.x, elevatorPosition.y + 64);

  static List<Rect> perimeterWalls(Vector2 size) => [
        Rect.fromLTWH(0, 0, size.x, 32),
        Rect.fromLTWH(0, size.y - 32, size.x, 32),
        Rect.fromLTWH(0, 0, 32, size.y),
        Rect.fromLTWH(size.x - 32, 0, 32, size.y),
      ];
}

/// Registry of the fixed layout for each floor.
abstract final class FloorLayouts {
  static final Vector2 elevatorPosition = Vector2(96, 96);

  static final Vector2 _smallFloorSize = Vector2(640, 448);

  static final FloorLayout lobby = FloorLayout(
    worldSize: _smallFloorSize.clone(),
    blockers: [
      ...FloorLayout.perimeterWalls(_smallFloorSize),
      // Reception desk.
      const Rect.fromLTWH(288, 96, 64, 64),
    ],
    elevatorPosition: elevatorPosition.clone(),
  );

  static final FloorLayout workspace = FloorLayout(
    worldSize: OfficeLayout.worldSize.clone(),
    blockers: OfficeLayout.blockers,
    elevatorPosition: elevatorPosition.clone(),
  );

  static final FloorLayout projectRoom = FloorLayout(
    worldSize: _smallFloorSize.clone(),
    blockers: [
      ...FloorLayout.perimeterWalls(_smallFloorSize),
      // Shared project table (two desks pushed together).
      const Rect.fromLTWH(288, 224, 64, 64),
      const Rect.fromLTWH(352, 224, 64, 64),
    ],
    elevatorPosition: elevatorPosition.clone(),
  );

  static final FloorLayout executive = FloorLayout(
    worldSize: _smallFloorSize.clone(),
    blockers: [
      ...FloorLayout.perimeterWalls(_smallFloorSize),
      // CEO desk.
      const Rect.fromLTWH(416, 288, 64, 64),
    ],
    elevatorPosition: elevatorPosition.clone(),
  );

  static FloorLayout forFloor(Floor floor) {
    switch (floor) {
      case Floor.lobby:
        return lobby;
      case Floor.workspace:
        return workspace;
      case Floor.projectRoom:
        return projectRoom;
      case Floor.executive:
        return executive;
    }
  }
}
