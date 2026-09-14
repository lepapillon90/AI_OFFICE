import 'package:ai_office/game/office_game.dart';
import 'package:ai_office/screens/board_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'typing a title enables "추가" and creates the card (regression: the '
      'title field used to have no onChanged, so the button stayed stuck '
      'disabled from its first, empty-text build)', (tester) async {
    final game = OfficeGame();
    // Matches production (see office_screen.dart): BoardPanel itself has no
    // Listenable wiring, it relies on a parent AnimatedBuilder listening to
    // `game` to rebuild it after every notifyListeners() call.
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: game,
          builder: (context, _) => BoardPanel(game: game, onClose: () {}),
        ),
      ),
    );

    await tester.tap(find.text('새 업무'));
    await tester.pumpAndSettle();

    final addButton = find.widgetWithText(TextButton, '추가');
    expect(tester.widget<TextButton>(addButton).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '새 카드');
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(addButton).onPressed, isNotNull);

    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(game.boardTasks, hasLength(1));
    expect(game.boardTasks.single.title, '새 카드');
  });

  testWidgets('설명 편집 saves a description onto the card', (tester) async {
    final game = OfficeGame();
    game.createBoardTask(title: '업무');
    // Matches production (see office_screen.dart): BoardPanel itself has no
    // Listenable wiring, it relies on a parent AnimatedBuilder listening to
    // `game` to rebuild it after every notifyListeners() call.
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: game,
          builder: (context, _) => BoardPanel(game: game, onClose: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_note));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '자세한 설명');
    await tester.tap(find.widgetWithText(TextButton, '저장'));
    await tester.pumpAndSettle();

    expect(game.boardTasks.single.description, '자세한 설명');
    expect(find.text('자세한 설명'), findsOneWidget);
  });

  // Drag-and-drop itself (Draggable -> DragTarget -> setBoardTaskStatus) is
  // covered at the OfficeGame level by board_test.dart's setBoardTaskStatus
  // tests, and was verified working in the real running app via manual
  // browser testing (dispatching a full pointerdown/move.../pointerup
  // sequence reliably triggers the drop; see docs/PHASE7_BOARD.md). A widget
  // test that drives Flutter's own Draggable/DragTarget gesture arena via
  // WidgetTester turned out to be flaky in ways unrelated to this feature's
  // own correctness, so it isn't included here.
}
