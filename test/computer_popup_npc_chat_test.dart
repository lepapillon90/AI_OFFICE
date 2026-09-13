import 'package:ai_office/game/office_game.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'openChatWithEmployee closes the computer popup and opens chat '
      'straight into that employee\'s room', () {
    final game = OfficeGame.forTest(playerPosition: Vector2(430, 350));
    game.handleInteractionKey(LogicalKeyboardKey.keyE);
    expect(game.isComputerPopupOpen, isTrue);

    final employee = game.nearbyEmployee!;
    game.openChatWithEmployee(employee);

    expect(game.isComputerPopupOpen, isFalse);
    expect(game.isChatOpen, isTrue);
    expect(game.pendingChatPeerName, employee.name);
  });

  test('lastReplyFrom is null before any exchange, then returns the reply',
      () async {
    final game = OfficeGame.forTest(playerPosition: Vector2(430, 350));
    final employee = game.nearbyEmployee!;

    expect(game.lastReplyFrom(employee), isNull);

    game.sendChatMessage('@${employee.name} 상태 보고해줘');
    // The NPC reply is dispatched via an unawaited Future even when
    // `askEmployee` is null (the no-auth fallback path still goes through
    // an async function), so let a couple of microtask turns flush.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final reply = game.lastReplyFrom(employee);
    expect(reply, isNotNull);
    expect(reply!.isNpc, isTrue);
    expect(reply.senderName, employee.name);
  });
}
