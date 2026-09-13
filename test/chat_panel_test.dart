import 'package:ai_office/game/office_game.dart';
import 'package:ai_office/screens/office_screen.dart';
import 'package:flame/components.dart';
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
}
