import 'dart:ui';

import 'package:ai_office/game/isometric/first_floor_asset_layout.dart';
import 'package:ai_office/game/isometric/first_floor_asset_manifest.dart';
import 'package:ai_office/game/isometric/iso_lobby_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('populates all six reference-image zones', () {
    expect(
      FirstFloorAssetLayout.placements
          .map((placement) => placement.zone)
          .toSet(),
      containsAll(<FirstFloorZone>[
        FirstFloorZone.topLobby,
        FirstFloorZone.cafe,
        FirstFloorZone.centralPlaza,
        FirstFloorZone.store,
        FirstFloorZone.lounge,
        FirstFloorZone.entranceLandscape,
      ]),
    );
  });

  test('keeps every v4 sprite within the unchanged 28 by 18 tile world', () {
    expect(IsoLobbyLayout.floorLayout.worldSize.x, 1792);
    expect(IsoLobbyLayout.floorLayout.worldSize.y, 1152);
    expect(FirstFloorAssetLayout.placements, isNotEmpty);
    const world = Rect.fromLTWH(0, 0, 1792, 1152);
    for (final placement in FirstFloorAssetLayout.placements) {
      expect(FirstFloorAssetManifest.all, contains(placement.assetPath));
      expect(placement.size.x, greaterThan(0));
      expect(placement.size.y, greaterThan(0));
      expect(world.intersect(placement.bounds), placement.bounds,
          reason: placement.assetPath);
    }
  });

  test('leaves two full tiles clear on every side of the central feature', () {
    final central = FirstFloorAssetLayout.placements
        .where((p) => p.zone == FirstFloorZone.centralPlaza)
        .toList();
    expect(central.map((p) => p.assetPath),
        contains(FirstFloorAssetManifest.centralPlanter));
    final featureBounds = central
        .map((p) => p.bounds)
        .reduce((bounds, next) => bounds.expandToInclude(next));
    final circulation = featureBounds.inflate(128);
    for (final placement in FirstFloorAssetLayout.placements
        .where((p) => p.zone != FirstFloorZone.centralPlaza)) {
      expect(placement.bounds.overlaps(circulation), isFalse,
          reason: '${placement.assetPath} obstructs the central circulation');
    }
  });
}
