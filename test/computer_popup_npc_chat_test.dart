import 'dart:async';

import 'package:ai_office/game/npc/npc_status.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:ai_office/screens/office_screen.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
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

  // These two need the NPC sprites actually mounted (their name tags are
  // set up in Component.onLoad), so — unlike the plain tests above, which
  // never touch NpcComponent — they pump a real widget tree rather than
  // constructing OfficeGame standalone.
  testWidgets(
      'an @employee command flips its status to working during the call, '
      'then restores its previous status on success', (tester) async {
    final completer = Completer<String>();
    final game = OfficeGame(
      askEmployee: ({
        required employeeName,
        required employeeRole,
        required command,
      }) =>
          completer.future,
    );
    await tester.pumpWidget(MaterialApp(home: OfficeScreen(game: game)));
    await tester.pump();

    final before = game.employees.firstWhere((e) => e.name == '노아');
    expect(before.status, NpcStatus.meeting, reason: 'sample data for 노아');

    game.sendChatMessage('@노아 상태 보고해줘');
    await tester.pump();

    final duringCall = game.employees.firstWhere((e) => e.name == '노아');
    expect(duringCall.status, NpcStatus.working);

    completer.complete('보고 끝났습니다');
    await tester.pump();
    await tester.pump();

    final afterCall = game.employees.firstWhere((e) => e.name == '노아');
    expect(afterCall.status, NpcStatus.meeting);
  });

  testWidgets('a failed @employee command sets its status to error',
      (tester) async {
    final game = OfficeGame(
      askEmployee: ({
        required employeeName,
        required employeeRole,
        required command,
      }) =>
          Future<String>.error('network boom'),
    );
    await tester.pumpWidget(MaterialApp(home: OfficeScreen(game: game)));
    await tester.pump();

    game.sendChatMessage('@유나 상태 보고해줘');
    await tester.pump();
    await tester.pump();

    final after = game.employees.firstWhere((e) => e.name == '유나');
    expect(after.status, NpcStatus.error);
  });
}
