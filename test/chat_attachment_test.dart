import 'dart:typed_data';

import 'package:ai_office/data/chat_message.dart';
import 'package:ai_office/game/npc/npc_usage.dart';
import 'package:ai_office/game/office_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sendChatAttachment', () {
    test('uploads the file and sends it as a public message when no room '
        'is selected', () async {
      String? uploadedName;
      final game = OfficeGame(
        uploadChatAttachment: ({required fileName, required bytes}) async {
          uploadedName = fileName;
          return 'company-1/123-$fileName';
        },
      );

      await game.sendChatAttachment(
        fileName: '기획서.pdf',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(uploadedName, '기획서.pdf');
      expect(game.chatMessages, hasLength(1));
      final message = game.chatMessages.single;
      expect(message.attachmentName, '기획서.pdf');
      expect(message.attachmentPath, 'company-1/123-기획서.pdf');
      expect(message.toUserId, isNull);
    });

    test('sends to the given room as a bare mention, without triggering an '
        'NPC command even when the room is an AI employee', () async {
      var askCalled = false;
      final game = OfficeGame(
        uploadChatAttachment: ({required fileName, required bytes}) async =>
            'path/$fileName',
        askEmployee: ({
          required employeeName,
          required employeeRole,
          required command,
          required history,
        }) async {
          askCalled = true;
          return const NpcCommandResult(reply: '완료');
        },
      );
      final hana = game.employees.firstWhere((e) => e.name == '하나');

      await game.sendChatAttachment(
        fileName: '참고자료.png',
        bytes: Uint8List.fromList([1]),
        toRoomName: hana.name,
      );
      // Give any (incorrectly) dispatched command a chance to run.
      await Future<void>.delayed(Duration.zero);

      expect(askCalled, isFalse);
      expect(game.chatMessages, hasLength(1));
      final message = game.chatMessages.single;
      expect(message.attachmentName, '참고자료.png');
      expect(message.toName, hana.name);
    });

    test('is a no-op when no uploader is configured (e.g. outside a '
        'signed-in session)', () async {
      final game = OfficeGame();

      await game.sendChatAttachment(
        fileName: 'x.txt',
        bytes: Uint8List.fromList([1]),
      );

      expect(game.chatMessages, isEmpty);
    });

    test('is a no-op when the upload fails (uploader returns null)',
        () async {
      final game = OfficeGame(
        uploadChatAttachment: ({required fileName, required bytes}) async =>
            null,
      );

      await game.sendChatAttachment(
        fileName: 'x.txt',
        bytes: Uint8List.fromList([1]),
      );

      expect(game.chatMessages, isEmpty);
    });
  });

  group('attachmentUrlFor', () {
    test('resolves the message\'s attachment path via the configured '
        'resolver', () async {
      final game = OfficeGame(
        resolveAttachmentUrl: (path) async => 'https://example.com/$path',
      );
      final message = ChatMessage(
        id: 'm1',
        userId: 'u1',
        senderName: '수히',
        body: '📎 x.txt',
        createdAt: DateTime.now(),
        attachmentPath: 'company-1/x.txt',
        attachmentName: 'x.txt',
      );

      final url = await game.attachmentUrlFor(message);

      expect(url, 'https://example.com/company-1/x.txt');
    });

    test('returns null for a message with no attachment', () async {
      final game = OfficeGame(
        resolveAttachmentUrl: (path) async => 'https://example.com/$path',
      );
      final message = ChatMessage(
        id: 'm1',
        userId: 'u1',
        senderName: '수히',
        body: 'hi',
        createdAt: DateTime.now(),
      );

      expect(await game.attachmentUrlFor(message), isNull);
    });

    test('returns null when no resolver is configured', () async {
      final game = OfficeGame();
      final message = ChatMessage(
        id: 'm1',
        userId: 'u1',
        senderName: '수히',
        body: '📎 x.txt',
        createdAt: DateTime.now(),
        attachmentPath: 'company-1/x.txt',
        attachmentName: 'x.txt',
      );

      expect(await game.attachmentUrlFor(message), isNull);
    });
  });
}
