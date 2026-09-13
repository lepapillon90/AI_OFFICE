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

/// First-floor configuration.
///
/// The floor foundation is a 28x18 grid of 64px tiles (1792x1152 world).
/// It deliberately contains no furniture or structure art: those will be
/// added only after the floor plan has been approved.
abstract final class IsoLobbyLayout {
  static const _floorTileSize = 64.0;
  static const _floorColumns = 28;
  static const _floorRows = 18;
  static final Vector2 _worldSize =
      Vector2(_floorColumns * _floorTileSize, _floorRows * _floorTileSize);

  static final List<Rect> wallBlockers =
      FloorLayout.perimeterWalls(_worldSize);

  static const List<Rect> furnitureBlockers = [];

  static final FloorLayout floorLayout = FloorLayout(
    worldSize: _worldSize.clone(),
    blockers: [
      ...wallBlockers,
      ...furnitureBlockers,
    ],
    elevatorPosition: Vector2(768, 128),
  );

  /// Tile-by-tile floor construction for the first floor.
  ///
  /// This intentionally uses the separate, named source tiles rather than a
  /// single painted background. It keeps each zone editable as the cafe,
  /// store, lobby, and outside areas are built out in later passes.
  static final List<IsoLobbyPlacement> placements = [
    ..._floorPlacements(),
  ];

  static List<IsoLobbyPlacement> _floorPlacements() {
    final tiles = <IsoLobbyPlacement>[];
    for (var row = 0; row < _floorRows; row++) {
      for (var column = 0; column < _floorColumns; column++) {
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
    const lastRow = _floorRows - 1;

    // The outdoor threshold at the lower edge establishes the entrance,
    // shallow ponds, and the planted borders before furniture is added —
    // column bands scaled up from the original 15-column layout's
    // (<=2 water / 3 planter / 6-8 entrance) split.
    if (row == lastRow) {
      if (column <= 3 || column >= 24) {
        return (
          category: 'shallow_water',
          variant: column == 1 || column == 26 ? 'variation_a' : 'base',
        );
      }
      if (column >= 11 && column <= 16) {
        return (category: 'indoor_entrance', variant: 'base');
      }
      if (column == 4 || column == 23) {
        return (category: 'planter_edge', variant: 'base');
      }
      return (category: 'pond_walkway', variant: 'base');
    }

    // The top band gives the lift and stair landing a colder stone finish —
    // scaled up from the original 3-row/3-column elevator alcove.
    if (row == 0) {
      return (
        category:
            column >= 11 && column <= 16 ? 'elevator_front' : 'stair_landing',
        variant: column == 11 || column == 16 ? 'edge' : 'base',
      );
    }
    if (row <= 3 && column >= 11 && column <= 16) {
      return (
        category: 'elevator_front',
        variant: row == 3 ? 'border_trim' : 'variation_a',
      );
    }

    // Commercial zones: cafe left, store right, and a softer lounge below.
    if (column <= 8 && row >= 6 && row <= 15) {
      return (
        category: 'cafe',
        variant: (column + row).isEven ? 'base' : 'variation_a',
      );
    }
    if (column >= 19 && row >= 6 && row <= 12) {
      return (
        category: 'store',
        variant: (column + row).isEven ? 'base' : 'variation_b',
      );
    }
    if (column >= 19 && row >= 13 && row <= 15) {
      return (
        category: 'lounge',
        variant: (column + row).isEven ? 'base' : 'variation_a',
      );
    }

    // A planted edge frames the middle without changing its walkable area.
    if ((column == 9 || column == 18) && row >= 6 && row <= 13) {
      return (
        category: 'planter_edge',
        variant: row == 6 || row == 11 ? 'transition' : 'border_trim',
      );
    }

    // The central circulation path uses the warmer reception lobby treatment.
    if (column >= 10 && column <= 17 && row >= 4 && row <= 8) {
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
