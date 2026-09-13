import 'dart:ui';

import 'package:ai_office/game/floors/floor_layout.dart';
import 'package:flame/components.dart';

/// A visual layer positioned at its foot point in the isometric lobby world.
class IsoLobbyPlacement {
  const IsoLobbyPlacement({
    required this.assetPath,
    required this.worldFootPoint,
    required this.screenSize,
    this.layerOffset = 0,
  });

  final String assetPath;
  final Vector2 worldFootPoint;
  final Vector2 screenSize;
  final int layerOffset;
}

/// Collision and layered-art configuration for the first-floor lobby.
abstract final class IsoLobbyLayout {
  static final Vector2 _worldSize = Vector2(960, 704);
  static const _floorTileSize = 64.0;

  // Exterior cutouts and their wall faces follow the stepped floor artwork.
  // Fill the exterior as well as the face so a large move cannot land outside.
  static const List<Rect> wallBlockers = [
    Rect.fromLTWH(0, 0, 960, 88),
    Rect.fromLTWH(0, 88, 352, 68),
    Rect.fromLTWH(608, 88, 352, 68),
    Rect.fromLTWH(0, 156, 256, 68),
    Rect.fromLTWH(704, 156, 256, 68),
    Rect.fromLTWH(0, 224, 36, 208),
    Rect.fromLTWH(924, 224, 36, 208),
    Rect.fromLTWH(0, 432, 240, 272),
    Rect.fromLTWH(720, 432, 240, 272),
    Rect.fromLTWH(240, 512, 96, 192),
    Rect.fromLTWH(624, 512, 96, 192),
    Rect.fromLTWH(336, 592, 288, 112),
  ];

  // Bases of the props, excluding their tall canopies and transparent padding.
  static const List<Rect> furnitureBlockers = [
    Rect.fromLTWH(400, 192, 160, 96),
    Rect.fromLTWH(96, 320, 240, 224),
    Rect.fromLTWH(624, 320, 240, 192),
    Rect.fromLTWH(400, 392, 160, 88), // Planter bed and surrounding pots.
    Rect.fromLTWH(634, 520, 220, 104), // Lounge seats and coffee table.
  ];

  static final FloorLayout floorLayout = FloorLayout(
    worldSize: _worldSize.clone(),
    blockers: [
      ...wallBlockers,
      ...furnitureBlockers,
    ],
    elevatorPosition: Vector2(480, 80),
  );

  /// Tile-by-tile floor construction for the first floor.
  ///
  /// This intentionally uses the separate, named source tiles rather than a
  /// single painted background. It keeps each zone editable as the cafe,
  /// store, lobby, and outside areas are built out in later passes.
  static final List<IsoLobbyPlacement> placements = [
    ..._floorPlacements(),
    IsoLobbyPlacement(
      assetPath: 'office_1f/isometric/reception.png',
      worldFootPoint: Vector2(480, 288),
      screenSize: Vector2(240, 240),
    ),
    IsoLobbyPlacement(
      assetPath: 'office_1f/isometric/cafe.png',
      worldFootPoint: Vector2(216, 544),
      screenSize: Vector2(300, 300),
    ),
    IsoLobbyPlacement(
      assetPath: 'office_1f/isometric/store.png',
      worldFootPoint: Vector2(744, 512),
      screenSize: Vector2(280, 280),
    ),
    IsoLobbyPlacement(
      assetPath: 'office_1f/isometric/lounge.png',
      worldFootPoint: Vector2(744, 640),
      screenSize: Vector2(240, 240),
    ),
    IsoLobbyPlacement(
      assetPath: 'office_1f/isometric/planters.png',
      worldFootPoint: Vector2(480, 480),
      screenSize: Vector2(220, 220),
    ),
    IsoLobbyPlacement(
      assetPath: 'office_1f/isometric/foreground.png',
      worldFootPoint: Vector2(480, 704),
      screenSize: Vector2(960, 240),
      layerOffset: 100000,
    ),
  ];

  static List<IsoLobbyPlacement> _floorPlacements() {
    final tiles = <IsoLobbyPlacement>[];
    for (var row = 0; row < 11; row++) {
      for (var column = 0; column < 15; column++) {
        final selection = _floorSelectionFor(column, row);
        tiles.add(
          IsoLobbyPlacement(
            assetPath: 'office_1f/v3/floor/${selection.category}/'
                '${selection.variant}.png',
            worldFootPoint: Vector2(
              column * _floorTileSize + _floorTileSize / 2,
              row * _floorTileSize + _floorTileSize,
            ),
            screenSize: Vector2.all(_floorTileSize),
            layerOffset: -100000,
          ),
        );
      }
    }
    return tiles;
  }

  static ({String category, String variant}) _floorSelectionFor(
    int column,
    int row,
  ) {
    // The outdoor threshold at the lower edge establishes the entrance,
    // shallow ponds, and the planted borders before furniture is added.
    if (row == 10) {
      if (column <= 2 || column >= 12) {
        return (
          category: 'shallow_water',
          variant: column == 1 || column == 13 ? 'variation_a' : 'base',
        );
      }
      if (column == 6 || column == 7 || column == 8) {
        return (category: 'indoor_entrance', variant: 'base');
      }
      if (column == 3 || column == 11) {
        return (category: 'planter_edge', variant: 'base');
      }
      return (category: 'pond_walkway', variant: 'base');
    }

    // The top band gives the lift and stair landing a colder stone finish.
    if (row == 0) {
      return (
        category:
            column >= 6 && column <= 8 ? 'elevator_front' : 'stair_landing',
        variant: column == 6 || column == 8 ? 'edge' : 'base',
      );
    }
    if (row <= 2 && column >= 6 && column <= 8) {
      return (
        category: 'elevator_front',
        variant: row == 2 ? 'border_trim' : 'variation_a',
      );
    }

    // Commercial zones: cafe left, store right, and a softer lounge below.
    if (column <= 4 && row >= 4 && row <= 9) {
      return (
        category: 'cafe',
        variant: (column + row).isEven ? 'base' : 'variation_a',
      );
    }
    if (column >= 10 && row >= 4 && row <= 7) {
      return (
        category: 'store',
        variant: (column + row).isEven ? 'base' : 'variation_b',
      );
    }
    if (column >= 10 && row >= 8 && row <= 9) {
      return (
        category: 'lounge',
        variant: (column + row).isEven ? 'base' : 'variation_a',
      );
    }

    // A planted edge frames the middle without changing its walkable area.
    if ((column == 5 || column == 9) && row >= 4 && row <= 8) {
      return (
        category: 'planter_edge',
        variant: row == 4 || row == 8 ? 'transition' : 'border_trim',
      );
    }

    // The central circulation path uses the warmer reception lobby treatment.
    if (column >= 5 && column <= 9 && row >= 3 && row <= 5) {
      return (
        category: 'reception_lobby',
        variant: (column + row).isEven ? 'base' : 'variation_a',
      );
    }
    return (
      category: 'main_lobby',
      variant: (column + row).isEven ? 'base' : 'variation_a',
    );
  }
}
