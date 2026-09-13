import 'dart:ui';

import 'package:flame/components.dart';

/// Fixed dimensions and collision rectangles for the office world.
///
/// Standard 2F canvas: 24x16 tiles at 64px each = 1536x1024.
abstract final class OfficeLayout {
  static const tileSize = 64.0;
  static const tileColumns = 24;
  static const tileRows = 16;

  static final Vector2 worldSize =
      Vector2(tileColumns * tileSize, tileRows * tileSize);

  /// Rendered size for character sprites (player and NPCs), smaller than the
  /// 64px source frame so characters read as human-scaled against the desks.
  static final Vector2 characterSize = Vector2.all(40);

  static const List<Rect> blockers = [
    // Perimeter walls.
    Rect.fromLTWH(0, 0, 1536, 32),
    Rect.fromLTWH(0, 992, 1536, 32),
    Rect.fromLTWH(0, 0, 32, 1024),
    Rect.fromLTWH(1504, 0, 32, 1024),

    // Meeting-room partition, with a doorway near the lounge.
    Rect.fromLTWH(800, 32, 32, 256),
    Rect.fromLTWH(800, 352, 32, 512),
    Rect.fromLTWH(800, 32, 416, 32),

    // Workstation desks.
    Rect.fromLTWH(384, 320, 64, 64),
    Rect.fromLTWH(544, 320, 64, 64),
    Rect.fromLTWH(384, 512, 64, 64),
    Rect.fromLTWH(544, 512, 64, 64),
  ];
}
