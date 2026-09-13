import 'dart:ui';

import 'package:ai_office/game/floors/floor_layout.dart';
import 'package:ai_office/game/floors/floor_map_component.dart';

/// 3rd floor: a shared project table for cross-team collaboration.
class ProjectRoomMap extends FloorMapComponent {
  ProjectRoomMap() : super(worldSize: FloorLayouts.projectRoom.worldSize);

  @override
  List<Rect> get wallRects => FloorLayout.perimeterWalls(size);

  @override
  List<(String, Rect)> get furniture => const [
        ('objects/desk.png', Rect.fromLTWH(288, 224, 64, 64)),
        ('objects/desk.png', Rect.fromLTWH(352, 224, 64, 64)),
        ('objects/computer.png', Rect.fromLTWH(288, 224, 64, 64)),
        ('objects/computer.png', Rect.fromLTWH(352, 224, 64, 64)),
        ('objects/chair.png', Rect.fromLTWH(288, 288, 64, 64)),
        ('objects/chair.png', Rect.fromLTWH(352, 288, 64, 64)),
        ('objects/plant.png', Rect.fromLTWH(480, 96, 64, 64)),
      ];
}
