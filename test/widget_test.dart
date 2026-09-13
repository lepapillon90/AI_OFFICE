import 'package:ai_office/game/office_game.dart';
import 'package:ai_office/screens/office_screen.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the office game screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OfficeScreen()));

    expect(find.byType(GameWidget<OfficeGame>), findsOneWidget);
  });

  testWidgets('loads the player sprite asset', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OfficeScreen()));
    await tester.pumpWidget(
      const MaterialApp(
        home: Image(
            image: AssetImage('assets/images/characters/office_worker.png')),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'shows the assigned AI employee popup when the game interaction opens',
      (tester) async {
    final game = OfficeGame.forTest(playerPosition: Vector2(430, 350));
    game.openComputerPopup();

    await tester.pumpWidget(MaterialApp(home: OfficeScreen(game: game)));

    expect(find.text('리아'), findsOneWidget);
    expect(find.text('백엔드 개발자'), findsOneWidget);
    expect(find.text('작업 중'), findsOneWidget);
    expect(find.text('대화하기'), findsOneWidget);
    expect(find.text('작업 확인'), findsOneWidget);
  });

  testWidgets('shows the computer prompt only while nearby and closed',
      (tester) async {
    final game = OfficeGame.forTest(playerPosition: Vector2(430, 350));

    await tester.pumpWidget(MaterialApp(home: OfficeScreen(game: game)));

    expect(find.text('[E] 리아 컴퓨터 사용'), findsOneWidget);
    game.openComputerPopup();
    await tester.pump();
    expect(find.text('[E] 리아 컴퓨터 사용'), findsNothing);
  });

  testWidgets('close button dismisses the computer popup', (tester) async {
    final game = OfficeGame.forTest(playerPosition: Vector2(430, 350));
    game.openComputerPopup();

    await tester.pumpWidget(MaterialApp(home: OfficeScreen(game: game)));
    await tester.tap(find.byTooltip('닫기'));
    await tester.pump();

    expect(game.isComputerPopupOpen, isFalse);
    expect(find.text('리아'), findsNothing);
    expect(find.text('[E] 리아 컴퓨터 사용'), findsOneWidget);
  });
}
