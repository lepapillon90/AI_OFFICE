import 'package:ai_office/game/office_game.dart';
import 'package:ai_office/screens/office_screen.dart';
import 'package:flame/components.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'switching between 공간 채팅 and 귓속말 · AI keeps whatever text was '
      'typed into the (shared) input field', (tester) async {
    final game = OfficeGame.forTest(playerPosition: Vector2(430, 350));
    game.openChat();
    await tester.pumpWidget(MaterialApp(home: OfficeScreen(game: game)));
    await tester.pump();

    final input = find.byType(TextField);
    expect(input, findsOneWidget);

    await tester.enterText(input, '아직 안 보낸 메시지');
    await tester.pump();
    expect(find.text('아직 안 보낸 메시지'), findsOneWidget);

    // Tap the 귓속말 · AI tab, then back to 공간 채팅.
    await tester.tap(find.text('귓속말 · AI'));
    await tester.pump();
    expect(find.text('아직 안 보낸 메시지'), findsOneWidget,
        reason: 'text survives switching to the whisper/AI tab');

    await tester.tap(find.text('공간 채팅'));
    await tester.pump();
    expect(find.text('아직 안 보낸 메시지'), findsOneWidget,
        reason: 'text survives switching back to the public tab');
  });

  testWidgets('a URL pasted into a public message renders as a tappable '
      'link, split out from the surrounding text', (tester) async {
    final game = OfficeGame.forTest(playerPosition: Vector2(430, 350));
    game.openChat();
    await tester.pumpWidget(MaterialApp(home: OfficeScreen(game: game)));
    await tester.pump();

    game.sendChatMessage('링크 https://mail.naver.com/v2/folders/-1/unread 확인');
    await tester.pump();

    final linkText = find.text('https://mail.naver.com/v2/folders/-1/unread');
    expect(linkText, findsOneWidget);
    expect(
      find.ancestor(of: linkText, matching: find.byType(GestureDetector)),
      findsOneWidget,
      reason: 'the URL itself is wrapped in a tappable region',
    );
    // The surrounding text is split into its own plain (non-tappable) Text
    // nodes, proving the message wasn't rendered as one untouched blob.
    expect(find.text('링크 '), findsOneWidget);
    expect(find.text(' 확인'), findsOneWidget);

    // Underlined only on hover, like a normal web link — not always. The
    // decoration itself stays TextDecoration.underline the whole time
    // (see _LinkSpan's build() for why); only its color toggles.
    final linkFinder = find.text('https://mail.naver.com/v2/folders/-1/unread');
    Text textOf() => tester.widget<Text>(linkFinder);
    expect(textOf().style?.decorationColor, Colors.transparent);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(linkFinder));
    await tester.pump();
    expect(textOf().style?.decorationColor, isNot(Colors.transparent));
  });

  testWidgets(
      'a message with no URL renders as one plain Text (not split/linkified)',
      (tester) async {
    final game = OfficeGame.forTest(playerPosition: Vector2(430, 350));
    game.openChat();
    await tester.pumpWidget(MaterialApp(home: OfficeScreen(game: game)));
    await tester.pump();

    game.sendChatMessage('그냥 일반 메시지입니다');
    await tester.pump();

    expect(find.text('그냥 일반 메시지입니다'), findsOneWidget);
  });
}
