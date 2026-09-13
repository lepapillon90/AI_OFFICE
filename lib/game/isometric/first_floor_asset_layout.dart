import 'dart:ui';

import 'package:ai_office/game/isometric/first_floor_asset_manifest.dart';
import 'package:flame/components.dart';

enum FirstFloorZone {
  topLobby,
  cafe,
  centralPlaza,
  store,
  lounge,
  entranceLandscape,
}

/// A visual sprite in the existing, unprojected 1792x1152 lobby world.
class FirstFloorAssetPlacement {
  const FirstFloorAssetPlacement({
    required this.assetPath,
    required this.position,
    required this.size,
    required this.zone,
    this.renderLayer = 0,
    this.anchor = Anchor.bottomCenter,
  });

  final String assetPath;
  final Vector2 position;
  final Vector2 size;
  final FirstFloorZone zone;
  final int renderLayer;
  final Anchor anchor;

  Rect get bounds => Rect.fromLTWH(
        position.x - size.x * anchor.x,
        position.y - size.y * anchor.y,
        size.x,
        size.y,
      );
}

abstract final class FirstFloorAssetLayout {
  /// Sizes preserve the source crops' aspect ratios. All positions are foot
  /// points; no additional isometric projection or collision bounds are added.
  static final List<FirstFloorAssetPlacement> placements = List.unmodifiable([
    ..._topLobby(),
    ..._cafe(),
    ..._centralPlaza(),
    ..._store(),
    ..._lounge(),
    ..._entranceLandscape(),
  ]);

  static FirstFloorAssetPlacement _place(
    String asset,
    FirstFloorZone zone,
    double x,
    double footY,
    double width,
    double height, {
    int layer = 0,
  }) =>
      FirstFloorAssetPlacement(
        assetPath: asset,
        position: Vector2(x, footY),
        size: Vector2(width, height),
        zone: zone,
        renderLayer: layer,
      );

  static List<FirstFloorAssetPlacement> _topLobby() {
    const zone = FirstFloorZone.topLobby;
    return [
      _place(FirstFloorAssetManifest.aiOfficeSign, zone, 280, 150, 340,
          340 * 345 / 890),
      _place(FirstFloorAssetManifest.lobbySofa, zone, 155, 270, 180,
          180 * 137 / 311),
      _place(FirstFloorAssetManifest.lobbySofa, zone, 415, 270, 180,
          180 * 137 / 311),
      _place(FirstFloorAssetManifest.lobbyTable, zone, 285, 322, 95,
          95 * 180 / 214),
      _place(FirstFloorAssetManifest.elevator, zone, 780, 222, 136,
          136 * 203 / 171),
      _place(FirstFloorAssetManifest.elevator, zone, 992, 222, 136,
          136 * 203 / 171),
      _place(FirstFloorAssetManifest.firstFloorSign, zone, 1097, 140, 80,
          80 * 274 / 384),
      _place(FirstFloorAssetManifest.reception, zone, 886, 374, 280,
          280 * 185 / 402),
      _place(FirstFloorAssetManifest.aiOfficeSign, zone, 1390, 144, 265,
          265 * 345 / 890),
      _place(FirstFloorAssetManifest.lobbySofa, zone, 1350, 278, 190,
          190 * 137 / 311),
      _place(FirstFloorAssetManifest.lobbyTable, zone, 1465, 325, 90,
          90 * 180 / 214),
      _place(FirstFloorAssetManifest.stairs, zone, 1640, 275, 157, 153),
    ];
  }

  static List<FirstFloorAssetPlacement> _cafe() {
    const zone = FirstFloorZone.cafe;
    return [
      _place(FirstFloorAssetManifest.aiCafeSign, zone, 290, 456, 250,
          250 * 240 / 680),
      _place(FirstFloorAssetManifest.cafeFixture, zone, 87, 506, 55,
          55 * 145 / 139),
      _place(FirstFloorAssetManifest.cafeFixture, zone, 493, 506, 55,
          55 * 145 / 139),
      _place(FirstFloorAssetManifest.cafeCounter, zone, 290, 674, 500,
          500 * 225 / 741),
      _place(FirstFloorAssetManifest.cafeTable, zone, 158, 837, 120, 120),
      _place(FirstFloorAssetManifest.cafeTable, zone, 422, 837, 120, 120),
      _place(FirstFloorAssetManifest.cafeTable, zone, 228, 985, 110, 110),
      _place(FirstFloorAssetManifest.cafeTable, zone, 358, 985, 110, 110),
    ];
  }

  static List<FirstFloorAssetPlacement> _centralPlaza() {
    const zone = FirstFloorZone.centralPlaza;
    // The complete feature occupies x=776..1016, y=531..820. Its 128px
    // circulation ring is x=648..1144, y=403..948 and contains no other art.
    return [
      _place(FirstFloorAssetManifest.centralPlanter, zone, 896, 772, 240,
          240 * 485 / 483),
      _place(FirstFloorAssetManifest.aiOfficeSign, zone, 896, 820, 128,
          128 * 345 / 890),
    ];
  }

  static List<FirstFloorAssetPlacement> _store() {
    const zone = FirstFloorZone.store;
    return [
      _place(FirstFloorAssetManifest.aiStoreSign, zone, 1496, 456, 250,
          250 * 235 / 651),
      _place(FirstFloorAssetManifest.storeShelves, zone, 1290, 648, 105,
          105 * 312 / 265),
      _place(FirstFloorAssetManifest.storeShelves, zone, 1437, 648, 105,
          105 * 312 / 265),
      _place(FirstFloorAssetManifest.storeFridge, zone, 1655, 660, 180,
          180 * 305 / 357),
      _place(FirstFloorAssetManifest.storeCounter, zone, 1495, 800, 245,
          245 * 274 / 480),
    ];
  }

  static List<FirstFloorAssetPlacement> _lounge() {
    const zone = FirstFloorZone.lounge;
    return [
      _place(FirstFloorAssetManifest.lobbySofa, zone, 1320, 940, 185,
          185 * 137 / 311),
      _place(FirstFloorAssetManifest.lobbySofa, zone, 1630, 940, 185,
          185 * 137 / 311),
      _place(FirstFloorAssetManifest.lobbyTable, zone, 1475, 994, 100,
          100 * 180 / 214),
      _place(FirstFloorAssetManifest.entrancePlanter, zone, 1740, 997, 52,
          52 * 155 / 100),
    ];
  }

  static List<FirstFloorAssetPlacement> _entranceLandscape() {
    const zone = FirstFloorZone.entranceLandscape;
    return [
      _place(
          FirstFloorAssetManifest.pond, zone, 280, 1136, 445, 445 * 115 / 461,
          layer: -1),
      _place(
          FirstFloorAssetManifest.pond, zone, 1512, 1136, 445, 445 * 115 / 461,
          layer: -1),
      _place(
          FirstFloorAssetManifest.fountain, zone, 280, 1110, 68, 68 * 122 / 98),
      _place(FirstFloorAssetManifest.fountain, zone, 1512, 1110, 68,
          68 * 122 / 98),
      _place(FirstFloorAssetManifest.landscape, zone, 94, 1058, 104,
          104 * 120 / 148),
      _place(FirstFloorAssetManifest.landscape, zone, 1698, 1058, 104,
          104 * 120 / 148),
      _place(FirstFloorAssetManifest.glassWall, zone, 614, 1140, 190,
          190 * 118 / 241),
      _place(FirstFloorAssetManifest.glassWall, zone, 1178, 1140, 190,
          190 * 118 / 241),
      _place(FirstFloorAssetManifest.entranceGlassDoor, zone, 896, 1140, 170,
          170 * 196 / 204),
      _place(FirstFloorAssetManifest.entrancePlanter, zone, 761, 1136, 58,
          58 * 155 / 100),
      _place(FirstFloorAssetManifest.entrancePlanter, zone, 1031, 1136, 58,
          58 * 155 / 100),
    ];
  }
}
