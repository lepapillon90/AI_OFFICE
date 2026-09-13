import 'package:ai_office/game/isometric/iso_projection.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a greater foot-point Y produces a greater priority', () {
    final near = IsoProjection.priorityFor(Vector2(96, 64));
    final far = IsoProjection.priorityFor(Vector2(96, 160));

    expect(far, greaterThan(near));
  });

  test('layer offset adds exactly to the base priority', () {
    final base = IsoProjection.priorityFor(Vector2(96, 160));
    final offset = IsoProjection.priorityFor(
      Vector2(96, 160),
      layerOffset: 10,
    );

    expect(offset, base + 10);
  });
}
