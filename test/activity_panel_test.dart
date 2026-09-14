import 'package:ai_office/game/activity/activity_event.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:ai_office/screens/activity_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<ActivityEvent> _seed() {
  final now = DateTime.now();
  return [
    ActivityEvent(
      id: '1',
      type: ActivityType.employee,
      message: '노아의 상태가 바뀌었습니다',
      createdAt: now,
      actorName: '수히',
    ),
    ActivityEvent(
      id: '2',
      type: ActivityType.aiCommand,
      message: '하나에게 보낸 명령이 성공했습니다',
      createdAt: now,
      actorName: '지민',
    ),
    ActivityEvent(
      id: '3',
      type: ActivityType.board,
      message: '"기획서 작성" 업무가 보드에 추가되었습니다',
      createdAt: now,
      actorName: '수히',
    ),
  ];
}

Future<void> _pump(WidgetTester tester, List<ActivityEvent> events) async {
  final game = OfficeGame(initialActivity: events);
  await tester.pumpWidget(MaterialApp(
    home: ActivityPanel(game: game, onClose: () {}),
  ));
  await tester.pump();
}

void main() {
  testWidgets('shows every event by default', (tester) async {
    await _pump(tester, _seed());

    expect(find.text('노아의 상태가 바뀌었습니다'), findsOneWidget);
    expect(find.text('하나에게 보낸 명령이 성공했습니다'), findsOneWidget);
    expect(find.text('"기획서 작성" 업무가 보드에 추가되었습니다'), findsOneWidget);
  });

  testWidgets('type filter chip narrows the list to that type only',
      (tester) async {
    await _pump(tester, _seed());

    await tester.tap(find.text('보드'));
    await tester.pump();

    expect(find.text('"기획서 작성" 업무가 보드에 추가되었습니다'), findsOneWidget);
    expect(find.text('노아의 상태가 바뀌었습니다'), findsNothing);
    expect(find.text('하나에게 보낸 명령이 성공했습니다'), findsNothing);
  });

  testWidgets('search matches the message text', (tester) async {
    await _pump(tester, _seed());

    await tester.enterText(find.byType(TextField), '기획서');
    await tester.pump();

    expect(find.text('"기획서 작성" 업무가 보드에 추가되었습니다'), findsOneWidget);
    expect(find.text('노아의 상태가 바뀌었습니다'), findsNothing);
  });

  testWidgets('search also matches the actor name', (tester) async {
    await _pump(tester, _seed());

    await tester.enterText(find.byType(TextField), '지민');
    await tester.pump();

    expect(find.text('하나에게 보낸 명령이 성공했습니다'), findsOneWidget);
    expect(find.text('노아의 상태가 바뀌었습니다'), findsNothing);
  });

  testWidgets('type filter and search combine (both must match)',
      (tester) async {
    await _pump(tester, _seed());

    await tester.tap(find.text('직원'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '지민');
    await tester.pump();

    // "노아의 상태가 바뀌었습니다" is type=employee but actor 수히, not 지민 —
    // so no event satisfies both filters at once.
    expect(find.text('노아의 상태가 바뀌었습니다'), findsNothing);
    expect(find.text('조건에 맞는 활동 기록이 없습니다.'), findsOneWidget);
  });

  testWidgets('clearing the search restores the full list', (tester) async {
    await _pump(tester, _seed());

    await tester.enterText(find.byType(TextField), '기획서');
    await tester.pump();
    expect(find.text('노아의 상태가 바뀌었습니다'), findsNothing);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();

    expect(find.text('노아의 상태가 바뀌었습니다'), findsOneWidget);
  });
}
