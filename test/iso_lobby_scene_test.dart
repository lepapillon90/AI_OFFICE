import 'package:ai_office/game/isometric/iso_floor_tiles_component.dart';
import 'package:ai_office/game/isometric/iso_lobby_layout.dart';
import 'package:ai_office/game/isometric/iso_lobby_scene.dart';
import 'package:ai_office/game/isometric/iso_projection.dart';
import 'package:ai_office/game/npc/ai_employee.dart';
import 'package:ai_office/game/npc/npc_component.dart';
import 'package:ai_office/game/npc/npc_status.dart';
import 'package:ai_office/game/player/office_player.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

List<IsoLobbyPlacement> get _floorPlacements => IsoLobbyLayout.placements
    .where((p) => p.assetPath.startsWith('office_1f/v3/floor/'))
    .toList();

List<IsoLobbyPlacement> get _overlayPlacements => IsoLobbyLayout.placements
    .where((p) => !p.assetPath.startsWith('office_1f/v3/floor/'))
    .toList();

void main() {
  test(
      'creates one floor-tile batch component plus one sprite component '
      'per overlay placement', () {
    final components = IsoLobbyScene().createComponents();

    expect(components, hasLength(1 + _overlayPlacements.length));
    expect(components.first, isA<IsoFloorTilesComponent>());
    expect(components.skip(1), everyElement(isA<IsoLobbySpriteComponent>()));
  });

  test('maps every overlay placement to its configured sprite component', () {
    final overlayPlacements = _overlayPlacements;
    final overlayComponents = IsoLobbyScene()
        .createComponents()
        .whereType<IsoLobbySpriteComponent>()
        .toList();

    expect(overlayComponents, hasLength(overlayPlacements.length));
    for (var index = 0; index < overlayComponents.length; index++) {
      final component = overlayComponents[index];
      final placement = overlayPlacements[index];

      expect(component.placement.assetPath, placement.assetPath);
      expect(component.position, placement.worldFootPoint);
      expect(component.size, placement.screenSize);
      expect(component.anchor, Anchor.bottomCenter);
      expect(
        component.priority,
        IsoProjection.priorityFor(
          placement.worldFootPoint,
          layerOffset: placement.layerOffset,
        ),
      );
    }
  });

  testWidgets(
      'the floor-tile batch loads one Sprite per unique asset and covers '
      'every placement — batched so entering the lobby stays fast even at '
      '${_floorPlacements.length} tiles', (tester) async {
    final floorPlacements = _floorPlacements;
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

  test('player and NPC accept dynamic render priorities', () {
    final player = OfficePlayer.forTest(position: Vector2(100, 100));
    final npc = NpcComponent(
      employee: const AiEmployee(
        id: 'npc-1',
        name: 'Test NPC',
        role: 'Developer',
        provider: 'test',
        workstationId: 'desk-1',
        status: NpcStatus.working,
      ),
      position: Vector2(200, 200),
    );

    player.setRenderPriority(320);
    npc.setRenderPriority(640);

    expect(player.priority, 320);
    expect(npc.priority, 640);
  });
}
