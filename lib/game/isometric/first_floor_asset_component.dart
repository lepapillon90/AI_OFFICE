import 'dart:ui';

import 'package:ai_office/game/isometric/first_floor_asset_layout.dart';
import 'package:flame/components.dart';

/// Visual-only objects above the floor and below the existing actors.
///
/// Assets are cached by path without grouping draw calls by path: preserving
/// layer/foot-point order lets pond fountains and foreground signs draw last.
/// Individual actor occlusion and collision remain outside this visual pass.
class FirstFloorAssetComponent extends PositionComponent {
  FirstFloorAssetComponent(List<FirstFloorAssetPlacement> placements)
      : _placements = List.of(placements)
          ..sort((a, b) {
            final layerOrder = a.renderLayer.compareTo(b.renderLayer);
            if (layerOrder != 0) return layerOrder;
            final depthOrder = a.position.y.compareTo(b.position.y);
            return depthOrder != 0
                ? depthOrder
                : a.position.x.compareTo(b.position.x);
          }),
        super(priority: -50000);

  final List<FirstFloorAssetPlacement> _placements;
  final Map<String, Sprite> _sprites = {};

  int get loadedAssetCount => _sprites.length;
  int get renderedAssetCount =>
      _placements.where((p) => _sprites.containsKey(p.assetPath)).length;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await Future.wait(
      _placements.map((p) => p.assetPath).toSet().map((path) async {
        _sprites[path] = await Sprite.load(path);
      }),
    );
  }

  @override
  void render(Canvas canvas) {
    for (final placement in _placements) {
      _sprites[placement.assetPath]?.render(
        canvas,
        position: placement.position,
        size: placement.size,
        anchor: placement.anchor,
      );
    }
  }
}
