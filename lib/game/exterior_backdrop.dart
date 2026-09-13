import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show LinearGradient, Alignment;

/// Fills the area outside the current floor's world bounds with a soft
/// sky-to-ground gradient instead of Flame's default solid black, so
/// letterboxed edges (smaller floors, zoomed-out camera) read as "outside
/// the building" rather than empty space.
///
/// Rendered as the camera's backdrop, so it's fixed to the viewport and
/// unaffected by panning/zooming the world.
class ExteriorBackdrop extends PositionComponent {
  static final _gradientColors = [
    const Color(0xFF8FCBEF),
    const Color(0xFFCFEAF6),
    const Color(0xFFBEE3B4),
  ];
  static const _gradientStops = [0.0, 0.55, 1.0];

  @override
  void onGameResize(Vector2 canvasSize) {
    super.onGameResize(canvasSize);
    size = canvasSize.clone();
  }

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: _gradientColors,
      stops: _gradientStops,
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }
}
