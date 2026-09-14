import 'package:ai_office/data/chat_message.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:ai_office/game/npc/npc_usage.dart';
import 'package:ai_office/screens/office_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Enough messages that the 320x460 chat panel can't show them all at
/// once, so a ScrollController's position actually has somewhere to be.
List<ChatMessage> _longPublicHistory() {
  final now = DateTime.now();
  return [
    for (var i = 0; i < 30; i++)
      ChatMessage(
        id: 'seed-$i',
        userId: 'someone-else',
        senderName: '동료',
        body: '메시지 $i',
        createdAt: now.add(Duration(seconds: i)),
      ),
  ];
}

Future<void> _openChat(WidgetTester tester, OfficeGame game) async {
  game.openChat();
  await tester.pumpWidget(MaterialApp(home: OfficeScreen(game: game)));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets(
      'opening 공간 채팅 with existing history starts scrolled to the latest '
      'message (regression: it used to always open scrolled to the oldest, '
      'top message)', (tester) async {
    final game = OfficeGame(initialChatMessages: _longPublicHistory());

    await _openChat(tester, game);

    // The 공간 채팅 list is always the first ListView in the IndexedStack
    // (see ChatPanel.build) regardless of which tab is currently showing —
    // both tabs' lists stay mounted, so index (not "first Scrollable
    // found") is what actually pins this down to the right one.
    final controller = tester.widget<ListView>(find.byType(ListView).at(0)).controller!;
    expect(controller.offset, controller.position.maxScrollExtent);
  });

  testWidgets(
      'a reply that lands asynchronously — never going through this '
      'panel\'s own send() — still scrolls its room to the bottom',
      (tester) async {
    final now = DateTime.now();
    final hanaRoomHistory = [
      for (var i = 0; i < 30; i++)
        ChatMessage(
          id: 'room-seed-$i',
          userId: 'local',
          toUserId: 'local',
          toName: '하나',
          senderName: '나',
          body: '이전 메시지 $i',
          createdAt: now.add(Duration(seconds: i)),
        ),
    ];
    final game = OfficeGame(
      initialChatMessages: hanaRoomHistory,
      askEmployee: ({
        required employeeName,
        required employeeRole,
        required command,
        required history,
      }) =>
          Future.value(const NpcCommandResult(reply: '완료했습니다')),
    );
    // Mirrors ComputerPopup's "대화하기"/board's "AI에게 지시": land straight
    // in that employee's room rather than the room list.
    final hana = game.employees.firstWhere((e) => e.name == '하나');
    game.openChatWithEmployee(hana);

    await _openChat(tester, game);

    // No public messages are seeded in this test, so the public tab's
    // _MessageList renders its empty-state Center(Text(...)) instead of a
    // ListView — the room's list ends up the only (and so first) ListView
    // in the tree.
    final controller = tester.widget<ListView>(find.byType(ListView).at(0)).controller!;
    // Scrolled away from the bottom, then the reply lands purely through
    // OfficeGame's own async dispatch — nothing in ChatPanel calls send().
    controller.jumpTo(0);
    expect(controller.offset, 0);

    game.sendChatMessage('@하나 상태 보고해줘');
    await tester.pump();
    await tester.pump();

    expect(controller.offset, controller.position.maxScrollExtent);
    expect(controller.offset, isNot(0));
  });
}
