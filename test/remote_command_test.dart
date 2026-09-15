import 'package:ai_office/data/remote_command.dart';
import 'package:ai_office/game/npc/npc_usage.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('@서버 chat command', () {
    test('"터미널 열어줘" runs open_terminal with no params, machineKey null',
        () async {
      RemoteCommandType? calledType;
      Map<String, dynamic>? calledParams;
      String? calledMachineKey;
      final game = OfficeGame(
        requestRemoteCommand: (type, params, machineKey) async {
          calledType = type;
          calledParams = params;
          calledMachineKey = machineKey;
          return '터미널을 열었습니다.';
        },
      );

      game.sendChatMessage('@서버 터미널 열어줘');
      await Future<void>.delayed(Duration.zero);

      expect(calledType, RemoteCommandType.openTerminal);
      expect(calledParams, isEmpty);
      expect(calledMachineKey, isNull);
      final reply = game.chatMessages.last;
      expect(reply.senderName, OfficeGame.remoteAgentName);
      expect(reply.body, '터미널을 열었습니다.');
      expect(reply.isNpc, isTrue);
    });

    test('"터미널 열어서 claude 실행해줘" runs open_terminal_claude', () async {
      RemoteCommandType? calledType;
      final game = OfficeGame(
        requestRemoteCommand: (type, params, machineKey) async {
          calledType = type;
          return '터미널을 열고 Claude CLI를 실행했습니다.';
        },
      );

      game.sendChatMessage('@서버 터미널 열어서 claude 실행해줘');
      await Future<void>.delayed(Duration.zero);

      expect(calledType, RemoteCommandType.openTerminalClaude);
    });

    test('"클로드 터미널 열어줘" (Korean transliteration) also runs '
        'open_terminal_claude', () async {
      RemoteCommandType? calledType;
      final game = OfficeGame(
        requestRemoteCommand: (type, params, machineKey) async {
          calledType = type;
          return 'ok';
        },
      );

      game.sendChatMessage('@서버 클로드 터미널 열어줘');
      await Future<void>.delayed(Duration.zero);

      expect(calledType, RemoteCommandType.openTerminalClaude);
    });

    test('"터미널 열어줘" without any claude mention still runs plain '
        'open_terminal', () async {
      RemoteCommandType? calledType;
      final game = OfficeGame(
        requestRemoteCommand: (type, params, machineKey) async {
          calledType = type;
          return 'ok';
        },
      );

      game.sendChatMessage('@서버 터미널 열어줘');
      await Future<void>.delayed(Duration.zero);

      expect(calledType, RemoteCommandType.openTerminal);
    });

    test('"OOO 폴더 만들어줘" runs create_folder with the extracted name',
        () async {
      RemoteCommandType? calledType;
      Map<String, dynamic>? calledParams;
      final game = OfficeGame(
        requestRemoteCommand: (type, params, machineKey) async {
          calledType = type;
          calledParams = params;
          return '바탕화면에 "보고서" 폴더를 만들었습니다.';
        },
      );

      game.sendChatMessage('@서버 보고서 폴더 만들어줘');
      await Future<void>.delayed(Duration.zero);

      expect(calledType, RemoteCommandType.createFolder);
      expect(calledParams, {'name': '보고서'});
      expect(game.chatMessages.last.body, '바탕화면에 "보고서" 폴더를 만들었습니다.');
    });

    test('extraneous phrasing ("바탕화면에 ... 폴더 만들어줘") is stripped from the '
        'extracted name', () async {
      Map<String, dynamic>? calledParams;
      final game = OfficeGame(
        requestRemoteCommand: (type, params, machineKey) async {
          calledParams = params;
          return 'ok';
        },
      );

      game.sendChatMessage('@서버 바탕화면에 기획안 폴더 만들어줘');
      await Future<void>.delayed(Duration.zero);

      expect(calledParams, {'name': '기획안'});
    });

    test('unsupported phrasing replies without calling the handler',
        () async {
      var called = false;
      final game = OfficeGame(
        requestRemoteCommand: (type, params, machineKey) async {
          called = true;
          return 'ok';
        },
      );

      game.sendChatMessage('@서버 오늘 날씨 어때');
      await Future<void>.delayed(Duration.zero);

      expect(called, isFalse);
      expect(game.chatMessages.last.body, contains('지원하지 않는 명령'));
    });

    test('no handler configured (e.g. outside a signed-in session) replies '
        'that the integration is unset, without throwing', () async {
      final game = OfficeGame();

      game.sendChatMessage('@서버 터미널 열어줘');
      await Future<void>.delayed(Duration.zero);

      expect(game.chatMessages.last.body, contains('설정되지 않았습니다'));
    });

    test('server machine switched off replies with a plain-language '
        'message and never calls the handler (no 45s wait for a dead '
        'agent to time out)', () async {
      var called = false;
      final game = OfficeGame(
        checkServerRunning: () async => false,
        requestRemoteCommand: (type, params, machineKey) async {
          called = true;
          return 'ok';
        },
      );

      game.sendChatMessage('@서버 터미널 열어줘');
      await Future<void>.delayed(Duration.zero);

      expect(called, isFalse);
      expect(game.chatMessages.last.body, contains('서버가 종료되어 있습니다'));
    });

    test('server machine switched on dispatches normally', () async {
      RemoteCommandType? calledType;
      final game = OfficeGame(
        checkServerRunning: () async => true,
        requestRemoteCommand: (type, params, machineKey) async {
          calledType = type;
          return '터미널을 열었습니다.';
        },
      );

      game.sendChatMessage('@서버 터미널 열어줘');
      await Future<void>.delayed(Duration.zero);

      expect(calledType, RemoteCommandType.openTerminal);
      expect(game.chatMessages.last.body, '터미널을 열었습니다.');
    });

    test('a bare "@서버" (no command) is just a private mention, not '
        'dispatched', () async {
      var called = false;
      final game = OfficeGame(
        requestRemoteCommand: (type, params, machineKey) async {
          called = true;
          return 'ok';
        },
      );

      game.sendChatMessage('@서버');
      await Future<void>.delayed(Duration.zero);

      expect(called, isFalse);
      expect(game.chatMessages, hasLength(1));
    });
  });

  group('@employee chat command (computer-linked whitelist)', () {
    test('a computer-linked employee\'s "터미널 열어줘" routes to the remote '
        'agent with that employee\'s workstationId as machineKey, replying '
        'as that employee (not 서버, not an LLM call)', () async {
      RemoteCommandType? calledType;
      String? calledMachineKey;
      var askEmployeeCalled = false;
      final game = OfficeGame(
        requestRemoteCommand: (type, params, machineKey) async {
          calledType = type;
          calledMachineKey = machineKey;
          return '터미널을 열었습니다.';
        },
        askEmployee: ({
          required employeeName,
          required employeeRole,
          required command,
          required history,
        }) async {
          askEmployeeCalled = true;
          return const NpcCommandResult(reply: '무슨 말씀이신지 모르겠어요');
        },
      );
      final linked = game.employees.first;
      game.updateEmployee(linked.copyWith(computerLinked: true));

      game.sendChatMessage('@${linked.name} 터미널 열어줘');
      await Future<void>.delayed(Duration.zero);

      expect(calledType, RemoteCommandType.openTerminal);
      expect(calledMachineKey, linked.workstationId);
      expect(askEmployeeCalled, isFalse);
      final reply = game.chatMessages.last;
      expect(reply.senderName, linked.name);
      expect(reply.body, '터미널을 열었습니다.');
    });

    test('an unlinked employee\'s "폴더 만들어줘" is treated as an ordinary '
        'chat command to the LLM, not a remote command', () async {
      var askEmployeeCalled = false;
      var remoteCalled = false;
      final game = OfficeGame(
        requestRemoteCommand: (type, params, machineKey) async {
          remoteCalled = true;
          return 'ok';
        },
        askEmployee: ({
          required employeeName,
          required employeeRole,
          required command,
          required history,
        }) async {
          askEmployeeCalled = true;
          return const NpcCommandResult(reply: '네, 폴더 정리해둘게요!');
        },
      );
      final unlinked = game.employees.first;
      expect(unlinked.computerLinked, isFalse);

      game.sendChatMessage('@${unlinked.name} 보고서 폴더 만들어줘');
      await Future<void>.delayed(Duration.zero);

      expect(remoteCalled, isFalse);
      expect(askEmployeeCalled, isTrue);
    });

    test('a computer-linked employee\'s ordinary conversation (no '
        '터미널/폴더 keyword) still goes to the LLM as usual', () async {
      var askEmployeeCalled = false;
      var remoteCalled = false;
      final game = OfficeGame(
        requestRemoteCommand: (type, params, machineKey) async {
          remoteCalled = true;
          return 'ok';
        },
        askEmployee: ({
          required employeeName,
          required employeeRole,
          required command,
          required history,
        }) async {
          askEmployeeCalled = true;
          return const NpcCommandResult(reply: '완료했습니다');
        },
      );
      final linked = game.employees.first;
      game.updateEmployee(linked.copyWith(computerLinked: true));

      game.sendChatMessage('@${linked.name} 오늘 할 일 정리해줘');
      await Future<void>.delayed(Duration.zero);

      expect(remoteCalled, isFalse);
      expect(askEmployeeCalled, isTrue);
    });
  });
}
