import 'package:ai_office/game/player/office_player.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stops before a blocking rectangle', () {
    final player = OfficePlayer.forTest(position: Vector2(350, 352));
    player.tryMove(Vector2(100, 0));
    expect(player.position.x, lessThan(400));
  });
}
