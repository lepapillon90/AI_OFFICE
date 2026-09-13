import 'dart:ui';

import 'package:flame/components.dart';

/// Base rendering for a floor's fixed layout: floor tiles, walls, and
/// furniture sprites. Subclasses just declare what walls and furniture to
/// place; tile-filling and sprite-loading are shared.
abstract class FloorMapComponent extends PositionComponent {
  FloorMapComponent({required Vector2 worldSize})
      : super(size: worldSize.clone());

  static const tileSize = 64.0;

  /// Wall rectangles rendered with the standard wall sprite.
  List<Rect> get wallRects;

  /// Furniture/decoration as (asset path, placement rect) pairs.
  List<(String, Rect)> get furniture;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    await _addFloorTiles();
    for (final rect in wallRects) {
      await add(await _sprite('tiles/walls/wall_00.png', rect));
    }
    for (final (asset, rect) in furniture) {
      await add(await _sprite(asset, rect));
    }
  }

  Future<void> _addFloorTiles() async {
    for (var y = 32.0; y < size.y - 32; y += tileSize) {
      for (var x = 32.0; x < size.x - 32; x += tileSize) {
        await add(
          await _sprite(
            'tiles/floor/floor_00.png',
            Rect.fromLTWH(x, y, tileSize, tileSize),
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
