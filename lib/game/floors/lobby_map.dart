import 'dart:ui';

import 'package:ai_office/game/floors/floor_layout.dart';
import 'package:ai_office/game/floors/floor_map_component.dart';

/// 1st floor: reception desk, cafe lounge with a sofa and coffee machine.
class LobbyMap extends FloorMapComponent {
  LobbyMap() : super(worldSize: FloorLayouts.lobby.worldSize);

  @override
  List<Rect> get wallRects => FloorLayout.perimeterWalls(size);

  @override
  List<(String, Rect)> get furniture => const [
        ('objects/desk.png', Rect.fromLTWH(288, 96, 64, 64)),
        ('objects/plant.png', Rect.fromLTWH(128, 96, 64, 64)),
        ('objects/sofa.png', Rect.fromLTWH(128, 288, 128, 64)),
        ('objects/coffee_machine.png', Rect.fromLTWH(400, 288, 64, 64)),
        ('objects/plant.png', Rect.fromLTWH(480, 288, 64, 64)),
      ];
}
