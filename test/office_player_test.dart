import 'package:ai_office/game/player/office_player.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stops before a blocking rectangle', () {
    final player = OfficePlayer.forTest(position: Vector2(350, 352));
    player.tryMove(Vector2(100, 0));
    expect(player.position.x, lessThan(400));
  });

  test('moves in the intended direction for every movement key', () {
    final cases = <Set<LogicalKeyboardKey>, Vector2>{
      {LogicalKeyboardKey.keyW}: Vector2(0, -1),
      {LogicalKeyboardKey.arrowUp}: Vector2(0, -1),
      {LogicalKeyboardKey.keyA}: Vector2(-1, 0),
      {LogicalKeyboardKey.arrowLeft}: Vector2(-1, 0),
      {LogicalKeyboardKey.keyS}: Vector2(0, 1),
      {LogicalKeyboardKey.arrowDown}: Vector2(0, 1),
      {LogicalKeyboardKey.keyD}: Vector2(1, 0),
      {LogicalKeyboardKey.arrowRight}: Vector2(1, 0),
    };

    for (final entry in cases.entries) {
      final player = _movedPlayer(entry.key);
      expect(player.position.x,
          entry.value.x == 0 ? 100 : 100 + entry.value.x * 18);
      expect(player.position.y,
          entry.value.y == 0 ? 100 : 100 + entry.value.y * 18);
    }
  });

  test('treats matching WASD and arrow keys as the same direction', () {
    final cases = <Set<LogicalKeyboardKey>, Vector2>{
      {LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp}: Vector2(0, -1),
      {LogicalKeyboardKey.keyA, LogicalKeyboardKey.arrowLeft}: Vector2(-1, 0),
      {LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowDown}: Vector2(0, 1),
      {LogicalKeyboardKey.keyD, LogicalKeyboardKey.arrowRight}: Vector2(1, 0),
    };

    for (final entry in cases.entries) {
      final player = _movedPlayer(entry.key);
      expect(player.position.x,
          entry.value.x == 0 ? 100 : 100 + entry.value.x * 18);
      expect(player.position.y,
          entry.value.y == 0 ? 100 : 100 + entry.value.y * 18);
    }
  });

  test('does not tunnel through a desk with a large horizontal delta', () {
    final player = OfficePlayer.forTest(position: Vector2(350, 352));

    player.tryMove(Vector2(140, 0));

    expect(player.position.x, 350);
  });

  test('does not tunnel through the meeting-room partition', () {
    final player = OfficePlayer.forTest(position: Vector2(750, 352));

    player.tryMove(Vector2(120, 0));

    expect(player.position.x, 750);
  });
}

OfficePlayer _movedPlayer(Set<LogicalKeyboardKey> keysPressed) {
  final player = OfficePlayer.forTest(position: Vector2(100, 100));
  player.onKeyEvent(
    const KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.arrowUp,
      logicalKey: LogicalKeyboardKey.arrowUp,
      timeStamp: Duration.zero,
    ),
    keysPressed,
  );
  player.update(.1);
  return player;
}
