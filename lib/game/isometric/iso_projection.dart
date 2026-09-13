import 'package:flame/components.dart';

abstract final class IsoProjection {
  static const _priorityScale = 100;

  static int priorityFor(Vector2 worldFootPoint, {int layerOffset = 0}) =>
      (worldFootPoint.y * _priorityScale).round() + layerOffset;
}
