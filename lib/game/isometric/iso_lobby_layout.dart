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
///
/// Base spec: a 24x16 grid of 64px tiles (1536x1024 world). The hand-placed
/// wall/furniture/overlay geometry below predates this grid — it was tuned
/// pixel-by-pixel for the previous 15x11/960x704 layout's artwork — so
/// until new art exists at the bigger canvas, [scaleX]/[scaleY] stretch it
/// proportionally rather than freehand redesigning the collision shapes.
/// [scaleX]/[scaleY] are exposed so tests can derive expectations from the
/// same factors instead of duplicating scaled magic numbers.
abstract final class IsoLobbyLayout {
  static const _floorTileSize = 64.0;
  static const _floorColumns = 24;
  static const _floorRows = 16;
  static final Vector2 _worldSize =
      Vector2(_floorColumns * _floorTileSize, _floorRows * _floorTileSize);

  static const scaleX = 1536 / 960; // 8/5
  static const scaleY = 1024 / 704; // 16/11

  static Rect _scaleRect(Rect rect) => Rect.fromLTWH(
        rect.left * scaleX,
        rect.top * scaleY,
        rect.width * scaleX,
        rect.height * scaleY,
      );

  static Vector2 _scalePoint(double x, double y) =>
      Vector2(x * scaleX, y * scaleY);

  // Exterior cutouts and their wall faces, at the original artwork's scale
  // (see the class doc comment) — [wallBlockers] below stretches these to
  // the current world size.
  static const List<Rect> _legacyWallBlockers = [
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

  // Bases of the props, excluding their tall canopies and transparent
  // padding — also at the original artwork's scale (see above).
  static const List<Rect> _legacyFurnitureBlockers = [
    Rect.fromLTWH(400, 192, 160, 96),
    Rect.fromLTWH(96, 320, 240, 224),
    Rect.fromLTWH(624, 320, 240, 192),
    Rect.fromLTWH(400, 392, 160, 88), // Planter bed and surrounding pots.
    Rect.fromLTWH(634, 520, 220, 104), // Lounge seats and coffee table.
  ];

  static final List<Rect> wallBlockers =
      _legacyWallBlockers.map(_scaleRect).toList();

  static final List<Rect> furnitureBlockers =
      _legacyFurnitureBlockers.map(_scaleRect).toList();

  static final FloorLayout floorLayout = FloorLayout(
    worldSize: _worldSize.clone(),
    blockers: [
      ...wallBlockers,
      ...furnitureBlockers,
    ],
    elevatorPosition: _scalePoint(480, 80),
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
      worldFootPoint: _scalePoint(480, 288),
      screenSize: Vector2(240, 240),
    ),
    IsoLobbyPlacement(
      assetPath: 'office_1f/isometric/cafe.png',
      worldFootPoint: _scalePoint(216, 544),
      screenSize: Vector2(300, 300),
    ),
    IsoLobbyPlacement(
      assetPath: 'office_1f/isometric/store.png',
      worldFootPoint: _scalePoint(744, 512),
      screenSize: Vector2(280, 280),
    ),
    IsoLobbyPlacement(
      assetPath: 'office_1f/isometric/lounge.png',
      worldFootPoint: _scalePoint(744, 640),
      screenSize: Vector2(240, 240),
    ),
    IsoLobbyPlacement(
      assetPath: 'office_1f/isometric/planters.png',
      worldFootPoint: _scalePoint(480, 480),
      screenSize: Vector2(220, 220),
    ),
    IsoLobbyPlacement(
      assetPath: 'office_1f/isometric/foreground.png',
      worldFootPoint: Vector2(_worldSize.x / 2, _worldSize.y),
      screenSize: Vector2(_worldSize.x, 240),
      layerOffset: 100000,
    ),
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
      if (column <= 3 || column >= 19) {
        return (
          category: 'shallow_water',
          variant: column == 1 || column == 22 ? 'variation_a' : 'base',
        );
      }
      if (column >= 9 && column <= 13) {
        return (category: 'indoor_entrance', variant: 'base');
      }
      if (column == 4 || column == 18) {
        return (category: 'planter_edge', variant: 'base');
      }
      return (category: 'pond_walkway', variant: 'base');
    }

    // The top band gives the lift and stair landing a colder stone finish —
    // scaled up from the original 3-row/3-column elevator alcove.
    if (row == 0) {
      return (
        category:
            column >= 9 && column <= 13 ? 'elevator_front' : 'stair_landing',
        variant: column == 9 || column == 13 ? 'edge' : 'base',
      );
    }
    if (row <= 3 && column >= 9 && column <= 13) {
      return (
        category: 'elevator_front',
        variant: row == 3 ? 'border_trim' : 'variation_a',
      );
    }

    // Commercial zones: cafe left, store right, and a softer lounge below.
    if (column <= 7 && row >= 6 && row <= 13) {
      return (
        category: 'cafe',
        variant: (column + row).isEven ? 'base' : 'variation_a',
      );
    }
    if (column >= 16 && row >= 6 && row <= 10) {
      return (
        category: 'store',
        variant: (column + row).isEven ? 'base' : 'variation_b',
      );
    }
    if (column >= 16 && row >= 11 && row <= 13) {
      return (
        category: 'lounge',
        variant: (column + row).isEven ? 'base' : 'variation_a',
      );
    }

    // A planted edge frames the middle without changing its walkable area.
    if ((column == 8 || column == 14) && row >= 6 && row <= 11) {
      return (
        category: 'planter_edge',
        variant: row == 6 || row == 11 ? 'transition' : 'border_trim',
      );
    }

    // The central circulation path uses the warmer reception lobby treatment.
    if (column >= 8 && column <= 14 && row >= 4 && row <= 7) {
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
