import 'package:ai_office/game/activity/activity_event.dart';
import 'package:ai_office/game/board/board_task.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('createBoardTask adds a "할 일" card, notifies, and logs activity',
      () {
    final game = OfficeGame.forTest(playerPosition: Vector2(430, 350));
    final hana = game.employees.firstWhere((e) => e.name == '하나');

    final task = game.createBoardTask(title: '채용 공고 검토', assignee: hana);

    expect(game.boardTasks, hasLength(1));
    expect(task.status, BoardTaskStatus.todo);
    expect(task.assigneeId, hana.id);
    expect(task.assigneeName, '하나');
    expect(game.activityLog, hasLength(1));
    expect(game.activityLog.first.type, ActivityType.board);
    expect(game.activityLog.first.message, contains('하나'));
  });

  test('moveBoardTask advances through columns and stops at each end', () {
    final game = OfficeGame.forTest(playerPosition: Vector2(430, 350));
    final task = game.createBoardTask(title: '테스트 업무');

    game.moveBoardTask(task.id, forward: false); // already at the start
    expect(game.boardTasks.single.status, BoardTaskStatus.todo);

    game.moveBoardTask(task.id, forward: true);
    expect(game.boardTasks.single.status, BoardTaskStatus.inProgress);

    game.moveBoardTask(task.id, forward: true);
    expect(game.boardTasks.single.status, BoardTaskStatus.done);

    game.moveBoardTask(task.id, forward: true); // already at the end
    expect(game.boardTasks.single.status, BoardTaskStatus.done);

    game.moveBoardTask(task.id, forward: false);
    expect(game.boardTasks.single.status, BoardTaskStatus.inProgress);
  });

  test('assignBoardTask reassigns and clears the assignee', () {
    final game = OfficeGame.forTest(playerPosition: Vector2(430, 350));
    final noah = game.employees.firstWhere((e) => e.name == '노아');
    final task = game.createBoardTask(title: '버그 수정');

    game.assignBoardTask(task.id, noah);
    expect(game.boardTasks.single.assigneeId, noah.id);

    game.assignBoardTask(task.id, null);
    expect(game.boardTasks.single.assigneeId, isNull);
    expect(game.boardTasks.single.assigneeName, isNull);
  });

  test('deleteBoardTask removes the card and calls onBoardTaskDeleted', () {
    String? deletedId;
    final game = OfficeGame(onBoardTaskDeleted: (id) => deletedId = id);
    final task = game.createBoardTask(title: '삭제될 업무');

    game.deleteBoardTask(task.id);

    expect(game.boardTasks, isEmpty);
    expect(deletedId, task.id);
  });

  test('onBoardTaskChanged fires on create, move, and assignment', () {
    final changes = <BoardTask>[];
    final game = OfficeGame(onBoardTaskChanged: changes.add);
    final noah = game.employees.firstWhere((e) => e.name == '노아');

    final task = game.createBoardTask(title: '업무 1');
    game.moveBoardTask(task.id, forward: true);
    game.assignBoardTask(task.id, noah);

    expect(changes, hasLength(3));
    expect(changes[0].status, BoardTaskStatus.todo);
    expect(changes[1].status, BoardTaskStatus.inProgress);
    expect(changes[2].assigneeId, noah.id);
  });

  test('initialBoardTasks seeds the board at startup', () {
    final now = DateTime.now();
    final seeded = BoardTask(
      id: 'restored-1',
      title: '복원된 업무',
      status: BoardTaskStatus.inProgress,
      createdAt: now,
      updatedAt: now,
    );
    final game = OfficeGame(initialBoardTasks: [seeded]);

    expect(game.boardTasks, hasLength(1));
    expect(game.boardTasks.single.id, 'restored-1');
  });

  test(
      'dispatchBoardTaskToAssignee opens chat with the assignee and sends '
      'the title as a command', () {
    final game = OfficeGame.forTest(playerPosition: Vector2(430, 350));
    final hana = game.employees.firstWhere((e) => e.name == '하나');
    final task = game.createBoardTask(title: '이번 주 채용 현황 정리', assignee: hana);

    game.dispatchBoardTaskToAssignee(task);

    expect(game.isChatOpen, isTrue);
    expect(game.pendingChatPeerName, '하나');
    // .last is the NPC's (fallback, askEmployee-less) reply — the command
    // itself is the message just before it.
    final sent = game.chatMessages.where((m) => !m.isNpc).last;
    expect(sent.body, '@하나 이번 주 채용 현황 정리');
    expect(sent.toName, '하나');
  });

  test('dispatchBoardTaskToAssignee is a no-op when unassigned', () {
    final game = OfficeGame.forTest(playerPosition: Vector2(430, 350));
    final task = game.createBoardTask(title: '담당자 없는 업무');

    game.dispatchBoardTaskToAssignee(task);

    expect(game.isChatOpen, isFalse);
    expect(game.chatMessages, isEmpty);
  });
}
