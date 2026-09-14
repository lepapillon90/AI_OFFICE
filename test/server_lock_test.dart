import 'package:ai_office/data/remote_command.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('server machine password lock', () {
    test('defaults to unlocked (no password configured)', () {
      final game = OfficeGame();
      expect(game.isServerUnlocked, isTrue);
    });

    test('initialServerUnlocked: false starts the session locked, and '
        '"@서버 ..." is refused without calling the handler', () async {
      var called = false;
      final game = OfficeGame(
        initialServerUnlocked: false,
        requestRemoteCommand: (type, params, machineKey) async {
          called = true;
          return 'ok';
        },
      );
      expect(game.isServerUnlocked, isFalse);

      game.sendChatMessage('@서버 터미널 열어줘');
      await Future<void>.delayed(Duration.zero);

      expect(called, isFalse);
      expect(game.chatMessages.last.body, contains('잠겨'));
    });

    test('a correct password unlocks the session and lets "@서버 ..." '
        'through afterward', () async {
      RemoteCommandType? calledType;
      final game = OfficeGame(
        initialServerUnlocked: false,
        verifyServerPassword: (attempt) async => attempt == 'hunter2',
        requestRemoteCommand: (type, params, machineKey) async {
          calledType = type;
          return '터미널을 열었습니다.';
        },
      );

      final wrongResult = await game.submitServerPassword('nope');
      expect(wrongResult, contains('올바르지 않습니다'));
      expect(game.isServerUnlocked, isFalse);

      final rightResult = await game.submitServerPassword('hunter2');
      expect(rightResult, contains('해제'));
      expect(game.isServerUnlocked, isTrue);

      game.sendChatMessage('@서버 터미널 열어줘');
      await Future<void>.delayed(Duration.zero);

      expect(calledType, RemoteCommandType.openTerminal);
    });

    test('an employee-linked computer is unaffected by the lock — still '
        'works even while the shared @서버 machine is locked', () async {
      var called = false;
      final game = OfficeGame(
        initialServerUnlocked: false,
        requestRemoteCommand: (type, params, machineKey) async {
          called = true;
          return '터미널을 열었습니다.';
        },
      );
      final linked = game.employees.first;
      game.updateEmployee(linked.copyWith(computerLinked: true));

      game.sendChatMessage('@${linked.name} 터미널 열어줘');
      await Future<void>.delayed(Duration.zero);

      expect(called, isTrue);
    });

    test('no verifier configured replies that the integration is unset, '
        'without throwing', () async {
      final game = OfficeGame(initialServerUnlocked: false);
      final result = await game.submitServerPassword('anything');
      expect(result, contains('설정되지 않았습니다'));
      expect(game.isServerUnlocked, isFalse);
    });
  });

  group('server machine power switch', () {
    test('fetchServerRunning relays the checker\'s result', () async {
      final game = OfficeGame(checkServerRunning: () async => true);
      expect(await game.fetchServerRunning(), isTrue);
    });

    test('fetchServerRunning defaults to false with no checker configured '
        '(e.g. outside a signed-in session)', () async {
      final game = OfficeGame();
      expect(await game.fetchServerRunning(), isFalse);
    });

    test('fetchServerRunning defaults to false if the checker throws',
        () async {
      final game = OfficeGame(
        checkServerRunning: () async => throw StateError('network error'),
      );
      expect(await game.fetchServerRunning(), isFalse);
    });

    test('updateServerRunning relays true/false to the setter and reports '
        'success', () async {
      bool? lastValue;
      final game = OfficeGame(
        setServerRunning: (running) async => lastValue = running,
      );

      final onResult = await game.updateServerRunning(true);
      expect(lastValue, isTrue);
      expect(onResult, contains('실행'));

      final offResult = await game.updateServerRunning(false);
      expect(lastValue, isFalse);
      expect(offResult, contains('종료'));
    });

    test('updateServerRunning with no setter configured replies that the '
        'integration is unset, without throwing', () async {
      final game = OfficeGame();
      final result = await game.updateServerRunning(true);
      expect(result, contains('설정되지 않았습니다'));
    });
  });
}
