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

  // Every workspace-floor tile shares one asset ('tiles/floor/floor_00.png')
  // across a 24x16 grid (384 tiles) — mounting that many separate
  // SpriteComponents (each with its own Sprite.load) was measurably slow to
  // load/mount, so they're drawn from a single loaded Sprite instead. See
  // IsoFloorTilesComponent's doc comment for the isometric lobby's version
  // of the same fix and why it mattered (docs/STATUS.md).
  Future<void> _addFloorTiles() async {
    final maxY = OfficeLayout.worldSize.y - 32;
    final maxX = OfficeLayout.worldSize.x - 32;
    final positions = <Vector2>[];
    for (var y = 32.0; y < maxY; y += _tileSize) {
      for (var x = 32.0; x < maxX; x += _tileSize) {
        positions.add(Vector2(x, y));
      }
    }
    await add(_TileBatchComponent(
      sprite: await Sprite.load('tiles/floor/floor_00.png'),
      positions: positions,
      tileSize: Vector2.all(_tileSize),
    ));
  }

  Future<SpriteComponent> _sprite(String assetPath, Rect bounds) async {
    return SpriteComponent(
      sprite: await Sprite.load(assetPath),
      position: Vector2(bounds.left, bounds.top),
      size: Vector2(bounds.width, bounds.height),
    );
  }
}

/// Draws one already-loaded [Sprite] at many top-left [positions] directly
/// on the canvas, instead of one [SpriteComponent] (and Sprite.load) per
/// position — see [OfficeMap._addFloorTiles]'s comment for why.
class _TileBatchComponent extends PositionComponent {
  _TileBatchComponent({
    required this.sprite,
    required this.positions,
    required this.tileSize,
  });

  final Sprite sprite;
  final List<Vector2> positions;
  final Vector2 tileSize;

  @override
  void render(Canvas canvas) {
    for (final position in positions) {
      sprite.render(canvas, position: position, size: tileSize);
    }
  }
}
