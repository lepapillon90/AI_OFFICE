import 'package:ai_office/game/isometric/iso_floor_tiles_component.dart';
import 'package:ai_office/game/isometric/iso_lobby_layout.dart';
import 'package:ai_office/game/isometric/iso_lobby_scene.dart';
import 'package:ai_office/game/isometric/iso_projection.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates only the floor-tile batch component', () {
    final components = IsoLobbyScene().createComponents();

    expect(components, hasLength(1));
    expect(components.first, isA<IsoFloorTilesComponent>());
  });

  testWidgets(
      'the floor-tile batch loads one Sprite per unique asset and covers '
      'every placement — batched so entering the lobby stays fast even at '
      '${IsoLobbyLayout.placements.length} tiles', (tester) async {
    final floorPlacements = IsoLobbyLayout.placements;
    final batch = IsoFloorTilesComponent(floorPlacements);
    final game = FlameGame()..add(batch);

    await tester.pumpWidget(
      Directionality(textDirection: TextDirection.ltr, child: GameWidget(game: game)),
    );
    await tester.runAsync(() async {
      await game.loaded;
      await game.ready();
    });
    await tester.pump();

    // Far fewer unique images than tiles — that gap is the whole point of
    // batching (one Sprite.load per distinct category/variant, reused for
    // every tile that shares it, instead of one per tile).
    final uniqueAssets = floorPlacements.map((p) => p.assetPath).toSet();
    expect(batch.loadedAssetCount, uniqueAssets.length);
    expect(batch.loadedAssetCount, lessThan(floorPlacements.length));
    expect(batch.renderedTileCount, floorPlacements.length);
    expect(
      batch.priority,
      IsoProjection.priorityFor(
        Vector2.zero(),
        layerOffset: floorPlacements.first.layerOffset,
      ),
    );
  });

}
