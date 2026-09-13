import 'dart:async';

import 'package:ai_office/game/npc/npc_status.dart';
import 'package:ai_office/game/npc/npc_task.dart';
import 'package:ai_office/game/npc/npc_usage.dart';
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
    final completer = Completer<NpcCommandResult>();
    final game = OfficeGame(
      askEmployee: ({
        required employeeName,
        required employeeRole,
        required command,
        required history,
      }) =>
          completer.future,
    );
    await tester.pumpWidget(MaterialApp(home: OfficeScreen(game: game)));
    await tester.pump();

    // Give 노아 a non-idle status first so restoring "whatever it was
    // before" is actually a meaningful check, not a no-op back to idle
    // (sample data now starts everyone idle — see sample_employees.dart).
    final noah = game.employees.firstWhere((e) => e.name == '노아');
    game.updateEmployee(noah.copyWith(status: NpcStatus.meeting));
    final before = game.employees.firstWhere((e) => e.name == '노아');
    expect(before.status, NpcStatus.meeting);

    game.sendChatMessage('@노아 상태 보고해줘');
    await tester.pump();

    final duringCall = game.employees.firstWhere((e) => e.name == '노아');
    expect(duringCall.status, NpcStatus.working);

    completer.complete(const NpcCommandResult(reply: '보고 끝났습니다'));
    await tester.pump();
    await tester.pump();

    final afterCall = game.employees.firstWhere((e) => e.name == '노아');
    expect(afterCall.status, NpcStatus.meeting);
  });

  testWidgets(
      'a failed @employee command retries once, then sets its status to '
      'error and records the failed attempts on its task history',
      (tester) async {
    var callCount = 0;
    final game = OfficeGame(
      askEmployee: ({
        required employeeName,
        required employeeRole,
        required command,
        required history,
      }) {
        callCount++;
        return Future<NpcCommandResult>.error('network boom');
      },
    );
    await tester.pumpWidget(MaterialApp(home: OfficeScreen(game: game)));
    await tester.pump();

    final yuna = game.employees.firstWhere((e) => e.name == '유나');
    game.sendChatMessage('@유나 상태 보고해줘');
    // Two attempts (the automatic retry-once-on-failure) each need their
    // own microtask turn to flush the already-errored Future.
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();

    final after = game.employees.firstWhere((e) => e.name == '유나');
    expect(after.status, NpcStatus.error);
    expect(callCount, 2);

    final tasks = game.tasksFor(yuna);
    expect(tasks, hasLength(1));
    expect(tasks.first.status, NpcTaskStatus.error);
    expect(tasks.first.attempts, 2);
  });

  testWidgets(
      'a successful @employee command is recorded on the task history with '
      'a single attempt', (tester) async {
    final game = OfficeGame(
      askEmployee: ({
        required employeeName,
        required employeeRole,
        required command,
        required history,
      }) =>
          Future.value(const NpcCommandResult(
            reply: '보고 끝났습니다',
            usage: NpcUsage(
              promptTokens: 120,
              completionTokens: 40,
              totalTokens: 160,
            ),
          )),
    );
    await tester.pumpWidget(MaterialApp(home: OfficeScreen(game: game)));
    await tester.pump();

    final noah = game.employees.firstWhere((e) => e.name == '노아');
    game.sendChatMessage('@노아 상태 보고해줘');
    await tester.pump();
    await tester.pump();

    final tasks = game.tasksFor(noah);
    expect(tasks, hasLength(1));
    expect(tasks.first.status, NpcTaskStatus.success);
    expect(tasks.first.attempts, 1);
    expect(tasks.first.result, '보고 끝났습니다');
    expect(tasks.first.usage?.totalTokens, 160);

    final usage = game.usageFor(noah);
    expect(usage.calls, 1);
    expect(usage.successes, 1);
    expect(usage.failures, 0);
    expect(usage.promptTokens, 120);
    expect(usage.completionTokens, 40);
    expect(usage.totalTokens, 160);
  });

  testWidgets(
      'usage accumulates across calls and counts every retry attempt',
      (tester) async {
    var callCount = 0;
    final game = OfficeGame(
      askEmployee: ({
        required employeeName,
        required employeeRole,
        required command,
        required history,
      }) {
        callCount++;
        if (callCount == 1) {
          // The first @유나 command fails, forcing the automatic retry —
          // both attempts should count toward her usage totals.
          return Future<NpcCommandResult>.error('network boom');
        }
        return Future.value(NpcCommandResult(
          reply: '답변 $callCount',
          usage: const NpcUsage(
            promptTokens: 10,
            completionTokens: 5,
            totalTokens: 15,
          ),
        ));
      },
    );
    await tester.pumpWidget(MaterialApp(home: OfficeScreen(game: game)));
    await tester.pump();

    final yuna = game.employees.firstWhere((e) => e.name == '유나');
    game.sendChatMessage('@유나 첫 명령');
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();

    // Attempt 1 failed, attempt 2 (still within the same command) succeeded.
    var usage = game.usageFor(yuna);
    expect(usage.calls, 2);
    expect(usage.successes, 1);
    expect(usage.failures, 1);
    expect(usage.totalTokens, 15);

    game.sendChatMessage('@유나 두번째 명령');
    await tester.pump();
    await tester.pump();

    usage = game.usageFor(yuna);
    expect(usage.calls, 3);
    expect(usage.successes, 2);
    expect(usage.failures, 1);
    expect(usage.totalTokens, 30);
    expect(game.totalUsage.calls, greaterThanOrEqualTo(usage.calls));
  });

  testWidgets(
      'a follow-up @employee command includes the prior exchange as history',
      (tester) async {
    List<Map<String, String>>? capturedHistory;
    final game = OfficeGame(
      askEmployee: ({
        required employeeName,
        required employeeRole,
        required command,
        required history,
      }) {
        capturedHistory = history;
        return Future.value(const NpcCommandResult(reply: '답변'));
      },
    );
    await tester.pumpWidget(MaterialApp(home: OfficeScreen(game: game)));
    await tester.pump();

    game.sendChatMessage('@하나 첫 번째 질문');
    await tester.pump();
    await tester.pump();
    expect(capturedHistory, isEmpty);

    game.sendChatMessage('@하나 두 번째 질문');
    await tester.pump();
    await tester.pump();

    expect(capturedHistory, [
      {'role': 'user', 'content': '첫 번째 질문'},
      {'role': 'assistant', 'content': '답변'},
    ]);
  });

  testWidgets(
      'onTaskChanged fires with the pending task and again with its '
      'resolved state', (tester) async {
    final changes = <NpcTask>[];
    final game = OfficeGame(
      askEmployee: ({
        required employeeName,
        required employeeRole,
        required command,
        required history,
      }) =>
          Future.value(const NpcCommandResult(reply: '완료')),
      onTaskChanged: changes.add,
    );
    await tester.pumpWidget(MaterialApp(home: OfficeScreen(game: game)));
    await tester.pump();

    game.sendChatMessage('@하나 상태 보고해줘');
    await tester.pump();
    await tester.pump();

    expect(changes, hasLength(2));
    expect(changes.first.status, NpcTaskStatus.pending);
    expect(changes.last.status, NpcTaskStatus.success);
    expect(changes.last.id, changes.first.id);
  });

  testWidgets(
      'onUsageEvent fires once per attempt, matching usageFor',
      (tester) async {
    final events = <bool>[];
    var callCount = 0;
    final game = OfficeGame(
      askEmployee: ({
        required employeeName,
        required employeeRole,
        required command,
        required history,
      }) {
        callCount++;
        if (callCount == 1) {
          return Future<NpcCommandResult>.error('boom');
        }
        return Future.value(const NpcCommandResult(reply: '완료'));
      },
      onUsageEvent: (employeeId, {required success, usage}) =>
          events.add(success),
    );
    await tester.pumpWidget(MaterialApp(home: OfficeScreen(game: game)));
    await tester.pump();

    game.sendChatMessage('@하나 상태 보고해줘');
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(events, [false, true]);
  });

  testWidgets(
      'generateDocument is called on success and its path lands on the '
      'task; documentUrlFor resolves it via resolveDocumentUrl',
      (tester) async {
    final game = OfficeGame(
      askEmployee: ({
        required employeeName,
        required employeeRole,
        required command,
        required history,
      }) =>
          Future.value(const NpcCommandResult(reply: '보고서 내용')),
      generateDocument: ({
        required employeeId,
        required employeeName,
        required taskId,
        required command,
        required result,
      }) =>
          Future.value('company-1/$employeeId/$taskId.txt'),
      resolveDocumentUrl: (path) =>
          Future.value('https://example.com/signed/$path'),
    );
    await tester.pumpWidget(MaterialApp(home: OfficeScreen(game: game)));
    await tester.pump();

    final hana = game.employees.firstWhere((e) => e.name == '하나');
    game.sendChatMessage('@하나 이번 주 채용 현황 정리해줘');
    await tester.pump();
    await tester.pump();

    final task = game.tasksFor(hana).first;
    expect(task.status, NpcTaskStatus.success);
    expect(task.documentPath, 'company-1/${hana.id}/${task.id}.txt');

    final url = await game.documentUrlFor(task);
    expect(url, 'https://example.com/signed/${task.documentPath}');
  });

  testWidgets(
      'documentUrlFor returns null for a task with no document or no '
      'resolver configured', (tester) async {
    final game = OfficeGame(
      askEmployee: ({
        required employeeName,
        required employeeRole,
        required command,
        required history,
      }) =>
          Future.value(const NpcCommandResult(reply: '완료')),
    );
    await tester.pumpWidget(MaterialApp(home: OfficeScreen(game: game)));
    await tester.pump();

    final hana = game.employees.firstWhere((e) => e.name == '하나');
    game.sendChatMessage('@하나 상태 보고해줘');
    await tester.pump();
    await tester.pump();

    final task = game.tasksFor(hana).first;
    expect(task.documentPath, isNull);
    expect(await game.documentUrlFor(task), isNull);
  });

  test('initialTasks and initialUsage seed tasksFor/usageFor at startup', () {
    final now = DateTime.now();
    final game = OfficeGame(
      initialTasks: [
        NpcTask(
          id: 'restored-1',
          employeeId: 'ai-4',
          command: '지난 명령',
          status: NpcTaskStatus.success,
          createdAt: now,
          result: '지난 결과',
        ),
      ],
      initialUsage: const {
        'ai-4': NpcUsageSummary(
          calls: 3,
          successes: 2,
          failures: 1,
          promptTokens: 100,
          completionTokens: 50,
        ),
      },
    );

    final hana = game.employees.firstWhere((e) => e.id == 'ai-4');
    final tasks = game.tasksFor(hana);
    expect(tasks, hasLength(1));
    expect(tasks.first.id, 'restored-1');

    final usage = game.usageFor(hana);
    expect(usage.calls, 3);
    expect(usage.successes, 2);
    expect(usage.failures, 1);
    expect(usage.totalTokens, 150);
  });
}
