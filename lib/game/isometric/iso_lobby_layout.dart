import 'package:ai_office/game/floors/floor_layout.dart';
import 'package:flame/components.dart';

/// Technical shell for the next first-floor map.
///
/// The former 28×18, 64px composition was intentionally removed. Artwork,
/// placements, and collision details will return only after the 48×32 map
/// design in `docs/first-floor/REBUILD_PLAN.md` is approved.
abstract final class IsoLobbyLayout {
  static const tileSize = 32.0;
  static const columns = 48;
  static const rows = 32;

  static final Vector2 worldSize = Vector2(
    columns * tileSize,
    rows * tileSize,
  );

  static final FloorLayout floorLayout = FloorLayout(
    worldSize: worldSize.clone(),
    blockers: FloorLayout.perimeterWalls(worldSize),
    // Temporary arrival point. Its exact visual placement is part of the
    // elevator-zone design pass, rather than a leftover coordinate.
    elevatorPosition: Vector2(worldSize.x / 2, tileSize * 4),
  );

  const IsoLobbyLayout._();
}
