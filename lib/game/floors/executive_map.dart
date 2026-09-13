import 'dart:ui';

import 'package:ai_office/game/floors/floor_layout.dart';
import 'package:ai_office/game/floors/floor_map_component.dart';

/// 4th floor: the CEO's private office.
class ExecutiveMap extends FloorMapComponent {
  ExecutiveMap() : super(worldSize: FloorLayouts.executive.worldSize);

  @override
  List<Rect> get wallRects => FloorLayout.perimeterWalls(size);

  @override
  List<(String, Rect)> get furniture => const [
        ('objects/desk.png', Rect.fromLTWH(416, 288, 64, 64)),
        ('objects/computer.png', Rect.fromLTWH(416, 288, 64, 64)),
        ('objects/chair.png', Rect.fromLTWH(416, 352, 64, 64)),
        ('objects/sofa.png', Rect.fromLTWH(128, 288, 128, 64)),
        ('objects/plant.png', Rect.fromLTWH(128, 160, 64, 64)),
      ];
}
