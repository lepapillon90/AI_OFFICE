import 'package:ai_office/game/npc/npc_status.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every activity event is relayed via notifySlack, with the same '
      'message text', () {
    final relayed = <String>[];
    final game = OfficeGame(
      notifySlack: (text) async => relayed.add(text),
    );
    final noah = game.employees.firstWhere((e) => e.name == '노아');

    game.updateEmployee(noah.copyWith(status: NpcStatus.meeting));

    expect(relayed, hasLength(1));
    expect(relayed.single, game.activityLog.first.message);
  });

  test('notifySlack is never called when not configured (e.g. outside a '
      'signed-in session)', () {
    final game = OfficeGame.forTest(playerPosition: Vector2(430, 350));
    final noah = game.employees.firstWhere((e) => e.name == '노아');

    // Would throw if OfficeGame tried to call a null notifySlack directly
    // instead of null-checking it first.
    game.updateEmployee(noah.copyWith(status: NpcStatus.meeting));

    expect(game.activityLog, hasLength(1));
  });

  test('a notifySlack failure does not affect the activity log itself',
      () async {
    final game = OfficeGame(
      notifySlack: (text) async => throw Exception('slack down'),
    );
    final noah = game.employees.firstWhere((e) => e.name == '노아');

    game.updateEmployee(noah.copyWith(status: NpcStatus.meeting));
    // Let the fire-and-forget Future's rejection settle.
    await Future<void>.delayed(Duration.zero);

    expect(game.activityLog, hasLength(1));
  });
}
