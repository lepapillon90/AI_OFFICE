import 'package:ai_office/game/activity/activity_event.dart';
import 'package:ai_office/game/npc/npc_status.dart';
import 'package:ai_office/game/npc/npc_usage.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:ai_office/screens/office_screen.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('updateEmployee logs a roster-edit activity event and bumps unread',
      () {
    final game = OfficeGame.forTest(playerPosition: Vector2(430, 350));
    expect(game.activityLog, isEmpty);
    expect(game.unreadActivityCount, 0);

    final noah = game.employees.firstWhere((e) => e.name == '노아');
    game.updateEmployee(noah.copyWith(status: NpcStatus.meeting));

    expect(game.activityLog, hasLength(1));
    expect(game.activityLog.first.type, ActivityType.employee);
    expect(game.activityLog.first.message, contains('노아'));
    expect(game.activityLog.first.message, contains('회의 중'));
    expect(game.unreadActivityCount, 1);
  });

  test('markActivityRead clears the unread count without clearing the log',
      () {
    final game = OfficeGame.forTest(playerPosition: Vector2(430, 350));
    final noah = game.employees.firstWhere((e) => e.name == '노아');
    game.updateEmployee(noah.copyWith(status: NpcStatus.meeting));
    expect(game.unreadActivityCount, 1);

    game.markActivityRead();

    expect(game.unreadActivityCount, 0);
    expect(game.activityLog, hasLength(1));
  });

  test('initialActivity seeds the activity log at startup', () {
    final seeded = ActivityEvent(
      id: 'restored-1',
      type: ActivityType.member,
      message: '테스트 시드 이벤트',
      createdAt: DateTime.now(),
    );
    final game = OfficeGame(initialActivity: [seeded]);

    expect(game.activityLog, hasLength(1));
    expect(game.activityLog.first.id, 'restored-1');
  });

  testWidgets(
      'a successful @employee command logs an ai_command activity event',
      (tester) async {
    final logged = <ActivityEvent>[];
    final game = OfficeGame(
      askEmployee: ({
        required employeeName,
        required employeeRole,
        required command,
        required history,
      }) =>
          Future.value(const NpcCommandResult(reply: '완료')),
      onActivityLogged: logged.add,
    );
    await tester.pumpWidget(MaterialApp(home: OfficeScreen(game: game)));
    await tester.pump();

    game.sendChatMessage('@하나 상태 보고해줘');
    await tester.pump();
    await tester.pump();

    expect(game.activityLog, hasLength(1));
    expect(game.activityLog.first.type, ActivityType.aiCommand);
    expect(game.activityLog.first.message, contains('하나'));
    expect(logged, hasLength(1));
    expect(logged.first.id, game.activityLog.first.id);
  });

  testWidgets(
      'a failed @employee command (after retry) logs an ai_command '
      'activity event too', (tester) async {
    final game = OfficeGame(
      askEmployee: ({
        required employeeName,
        required employeeRole,
        required command,
        required history,
      }) =>
          Future<NpcCommandResult>.error('boom'),
    );
    await tester.pumpWidget(MaterialApp(home: OfficeScreen(game: game)));
    await tester.pump();

    game.sendChatMessage('@유나 상태 보고해줘');
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(game.activityLog, hasLength(1));
    expect(game.activityLog.first.type, ActivityType.aiCommand);
    expect(game.activityLog.first.message, contains('실패'));
  });
}
