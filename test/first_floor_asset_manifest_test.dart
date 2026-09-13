import 'dart:io';

import 'package:ai_office/game/isometric/first_floor_asset_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exposes usable core first-floor sprites', () {
    final coreAssets = <String>[
      FirstFloorAssetManifest.elevator,
      FirstFloorAssetManifest.centralPlanter,
      FirstFloorAssetManifest.cafeCounter,
      FirstFloorAssetManifest.storeShelves,
      FirstFloorAssetManifest.glassDoor,
    ];

    expect(FirstFloorAssetManifest.all, containsAll(coreAssets));
    for (final assetPath in coreAssets) {
      expect(File('assets/images/$assetPath').existsSync(), isTrue);
    }
  });
}
