import 'dart:ui';

import 'package:ai_office/game/map/office_layout.dart';
import 'package:flame/components.dart';

/// Renders the fixed office plan using the supplied tile and object artwork.
class OfficeMap extends PositionComponent {
  OfficeMap() : super(size: OfficeLayout.worldSize.clone());

  static const _tileSize = 64.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final worldWidth = OfficeLayout.worldSize.x;
    final worldHeight = OfficeLayout.worldSize.y;

    await _addFloorTiles();
    await addAll([
      await _sprite(
          'tiles/walls/wall_00.png', Rect.fromLTWH(0, 0, worldWidth, 32)),
      await _sprite('tiles/walls/wall_00.png',
          Rect.fromLTWH(0, worldHeight - 32, worldWidth, 32)),
      await _sprite(
          'tiles/walls/wall_00.png', Rect.fromLTWH(0, 0, 32, worldHeight)),
      await _sprite('tiles/walls/wall_00.png',
          Rect.fromLTWH(worldWidth - 32, 0, 32, worldHeight)),
      await _sprite(
          'tiles/walls/wall_00.png', const Rect.fromLTWH(800, 32, 32, 256)),
      await _sprite(
          'tiles/walls/wall_00.png', const Rect.fromLTWH(800, 352, 32, 512)),
      await _sprite(
          'tiles/walls/wall_00.png', const Rect.fromLTWH(800, 32, 416, 32)),
      await _sprite('objects/desk.png', const Rect.fromLTWH(384, 320, 64, 64)),
      await _sprite(
          'objects/computer.png', const Rect.fromLTWH(384, 320, 64, 64)),
      await _sprite('objects/chair.png', const Rect.fromLTWH(384, 384, 64, 64)),
      await _sprite('objects/desk.png', const Rect.fromLTWH(544, 320, 64, 64)),
      await _sprite(
          'objects/computer.png', const Rect.fromLTWH(544, 320, 64, 64)),
      await _sprite('objects/chair.png', const Rect.fromLTWH(544, 384, 64, 64)),
      await _sprite('objects/desk.png', const Rect.fromLTWH(384, 512, 64, 64)),
      await _sprite(
          'objects/computer.png', const Rect.fromLTWH(384, 512, 64, 64)),
      await _sprite('objects/chair.png', const Rect.fromLTWH(384, 576, 64, 64)),
      await _sprite('objects/desk.png', const Rect.fromLTWH(544, 512, 64, 64)),
      await _sprite(
          'objects/computer.png', const Rect.fromLTWH(544, 512, 64, 64)),
      await _sprite('objects/chair.png', const Rect.fromLTWH(544, 576, 64, 64)),
      await _sprite('objects/sofa.png', const Rect.fromLTWH(960, 480, 128, 64)),
      await _sprite(
          'objects/coffee_machine.png', const Rect.fromLTWH(1088, 480, 64, 64)),
      await _sprite('objects/plant.png', const Rect.fromLTWH(960, 576, 64, 64)),
    ]);
  }

  Future<void> _addFloorTiles() async {
    final maxY = OfficeLayout.worldSize.y - 32;
    final maxX = OfficeLayout.worldSize.x - 32;
    for (var y = 32.0; y < maxY; y += _tileSize) {
      for (var x = 32.0; x < maxX; x += _tileSize) {
        await add(
          await _sprite(
            'tiles/floor/floor_00.png',
            Rect.fromLTWH(x, y, _tileSize, _tileSize),
          ),
        );
      }
    }
  }

  Future<SpriteComponent> _sprite(String assetPath, Rect bounds) async {
    return SpriteComponent(
      sprite: await Sprite.load(assetPath),
      position: Vector2(bounds.left, bounds.top),
      size: Vector2(bounds.width, bounds.height),
    );
  }
}
