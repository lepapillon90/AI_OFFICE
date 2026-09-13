import 'dart:ui';

import 'package:ai_office/game/isometric/iso_lobby_layout.dart';
import 'package:ai_office/game/isometric/iso_projection.dart';
import 'package:flame/components.dart';

/// Renders every isometric-lobby floor tile from one loaded [Sprite] per
/// *unique* asset — drawn directly onto the canvas rather than mounted as
/// its own [SpriteComponent] — instead of Flame loading and mounting a
/// separate component per tile (the previous approach — see
/// [IsoLobbyScene]). At the current 24x16 grid that's ~380 tile
/// placements sharing only a couple dozen distinct images (each floor
/// category/variant combination repeats many times); loading — and
/// especially *mounting* — that many components individually was slow
/// enough to time out a real floor-switch test
/// (`test/lobby_runtime_test.dart`, see docs/STATUS.md).
///
/// This is safe specifically for floor tiles because they never need
/// individual depth-sorting against the player/NPCs — every tile shares
/// the same very-negative [IsoLobbyPlacement.layerOffset] so the whole
/// floor always renders behind everything else regardless of row. The
/// overlay art (reception/cafe/store/lounge/planters/foreground) still
/// needs per-placement world priority to interleave correctly with the
/// player, so [IsoLobbyScene] keeps those as separate top-level
/// [IsoLobbySpriteComponent]s.
class IsoFloorTilesComponent extends PositionComponent {
  IsoFloorTilesComponent(this._placements)
      : super(
          priority: IsoProjection.priorityFor(
            Vector2.zero(),
            layerOffset:
                _placements.isEmpty ? 0 : _placements.first.layerOffset,
          ),
        );

  final List<IsoLobbyPlacement> _placements;

  /// Placements grouped by asset path, each holding the one [Sprite]
  /// loaded for that path — populated once in [onLoad].
  List<({Sprite sprite, List<IsoLobbyPlacement> placements})> _batches = [];

  /// How many distinct images were actually loaded (one [Sprite.load] per
  /// unique asset path, not per tile) — exposed for tests.
  int get loadedAssetCount => _batches.length;

  /// How many tile placements are covered across all loaded batches —
  /// should equal the placements this was constructed with, once loaded.
  int get renderedTileCount =>
      _batches.fold(0, (sum, batch) => sum + batch.placements.length);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final placementsByAsset = <String, List<IsoLobbyPlacement>>{};
    for (final placement in _placements) {
      placementsByAsset.putIfAbsent(placement.assetPath, () => []).add(placement);
    }
    _batches = await Future.wait(placementsByAsset.entries.map((entry) async {
      final sprite = await Sprite.load(entry.key);
      return (sprite: sprite, placements: entry.value);
    }));
  }

  @override
  void render(Canvas canvas) {
    for (final batch in _batches) {
      for (final placement in batch.placements) {
        batch.sprite.render(
          canvas,
          position: placement.worldFootPoint,
          size: placement.screenSize,
          anchor: Anchor.bottomCenter,
        );
      }
    }
  }
}
