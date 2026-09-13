import 'dart:ui';

import 'package:flame/components.dart';

/// Fixed dimensions and collision rectangles for the office world.
abstract final class OfficeLayout {
  static final Vector2 worldSize = Vector2(1280, 896);

  static const List<Rect> blockers = [
    // Perimeter walls.
    Rect.fromLTWH(0, 0, 1280, 32),
    Rect.fromLTWH(0, 864, 1280, 32),
    Rect.fromLTWH(0, 0, 32, 896),
    Rect.fromLTWH(1248, 0, 32, 896),

    // Meeting-room partition, with a doorway near the lounge.
    Rect.fromLTWH(800, 32, 32, 256),
    Rect.fromLTWH(800, 352, 32, 512),
    Rect.fromLTWH(800, 32, 416, 32),

    // Workstation desks.
    Rect.fromLTWH(384, 320, 64, 64),
    Rect.fromLTWH(544, 320, 64, 64),
    Rect.fromLTWH(384, 512, 64, 64),
  ];
}
