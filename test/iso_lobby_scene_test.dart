import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_office/game/isometric/first_floor_asset_component.dart';
import 'package:ai_office/game/isometric/first_floor_asset_layout.dart';
import 'package:ai_office/game/isometric/first_floor_asset_manifest.dart';
import 'package:ai_office/game/isometric/iso_floor_tiles_component.dart';
import 'package:ai_office/game/isometric/iso_lobby_layout.dart';
import 'package:ai_office/game/isometric/iso_lobby_scene.dart';
import 'package:ai_office/game/isometric/iso_projection.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates the floor tiles followed by the first-floor asset layer', () {
    final components = IsoLobbyScene().createComponents();

    expect(components, hasLength(2));
    expect(components.first, isA<IsoFloorTilesComponent>());
    expect(components.last, isA<FirstFloorAssetComponent>());
    expect(components.last.priority, greaterThan(components.first.priority));
  });

  testWidgets(
      'the floor-tile batch loads one Sprite per unique asset and covers '
      'every placement — batched so entering the lobby stays fast even at '
      '${IsoLobbyLayout.placements.length} tiles', (tester) async {
    final floorPlacements = IsoLobbyLayout.placements;
    final batch = IsoFloorTilesComponent(floorPlacements);
    final game = FlameGame()..add(batch);

    await tester.pumpWidget(
      Directionality(
          textDirection: TextDirection.ltr, child: GameWidget(game: game)),
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

  testWidgets('loads each object sprite once and renders the complete scene',
      (tester) async {
    final components = IsoLobbyScene().createComponents();
    final batch = components.last as FirstFloorAssetComponent;
    final game = FlameGame()..addAll(components);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: GameWidget(game: game),
      ),
    );
    await tester.runAsync(() async {
      await game.loaded;
      await game.ready();
    });
    await tester.pump();

    final uniqueAssets = FirstFloorAssetLayout.placements
        .map((placement) => placement.assetPath)
        .toSet();
    expect(batch.loadedAssetCount, uniqueAssets.length);
    expect(batch.loadedAssetCount,
        lessThan(FirstFloorAssetLayout.placements.length));

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    for (final component in components) {
      component.render(canvas);
    }
    expect(batch.renderedAssetCount, FirstFloorAssetLayout.placements.length);
    final picture = recorder.endRecording();
    // Optional, full-world visual QA artifact from the actual Flame renderers.
    final previewPath = Platform.environment['FIRST_FLOOR_PREVIEW'];
    if (previewPath != null) {
      await tester.runAsync(() async {
        final image = await picture.toImage(1792, 1152);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(previewPath).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    picture.dispose();
  });

  testWidgets('renders sprite sizes and anchors in layer order',
      (tester) async {
    final batch = FirstFloorAssetComponent([
      FirstFloorAssetPlacement(
        assetPath: FirstFloorAssetManifest.cafeFixture,
        position: Vector2(75, 60),
        size: Vector2(50, 50),
        zone: FirstFloorZone.cafe,
        renderLayer: 1,
      ),
      FirstFloorAssetPlacement(
        assetPath: FirstFloorAssetManifest.pond,
        position: Vector2(30, 70),
        size: Vector2(90, 50),
        zone: FirstFloorZone.entranceLandscape,
        anchor: Anchor.bottomLeft,
      ),
    ]);
    await tester.runAsync(() async {
      await batch.onLoad();
      final actualRecorder = ui.PictureRecorder();
      batch.render(ui.Canvas(actualRecorder));
      final expectedRecorder = ui.PictureRecorder();
      final expectedCanvas = ui.Canvas(expectedRecorder);
      // Hand-derived rectangles: the pond is behind the fixture despite its
      // greater foot Y and its later position in the input list.
      (await Sprite.load(FirstFloorAssetManifest.pond)).render(
        expectedCanvas,
        position: Vector2(30, 20),
        size: Vector2(90, 50),
      );
      (await Sprite.load(FirstFloorAssetManifest.cafeFixture)).render(
        expectedCanvas,
        position: Vector2(50, 10),
        size: Vector2(50, 50),
      );
      final actualPicture = actualRecorder.endRecording();
      final expectedPicture = expectedRecorder.endRecording();
      final actual = await actualPicture.toImage(160, 100);
      final expected = await expectedPicture.toImage(160, 100);
      final actualBytes = await actual.toByteData();
      final expectedBytes = await expected.toByteData();
      expect(
        listEquals(actualBytes!.buffer.asUint8List(),
            expectedBytes!.buffer.asUint8List()),
        isTrue,
        reason: 'Rendered pixels must respect size, anchor and render layer',
      );
      actual.dispose();
      expected.dispose();
      actualPicture.dispose();
      expectedPicture.dispose();
    });
  });
}
