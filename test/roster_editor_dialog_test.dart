import 'package:ai_office/game/office_game.dart';
import 'package:ai_office/screens/roster_editor_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'toggling "실제 컴퓨터와 연결" persists the change and the checkbox '
      'visibly reflects it (regression: the checkbox is a controlled '
      "widget — unlike the status dropdown's initialValue caching, it "
      'needs a local setState or it silently stays unchecked even though '
      'the underlying employee did update)', (tester) async {
    final game = OfficeGame();
    final employee = game.employees.first;
    expect(employee.computerLinked, isFalse);

    await tester.pumpWidget(MaterialApp(
      home: RosterEditorDialog(game: game),
    ));
    await tester.pump();

    final checkboxFinder = find.byType(CheckboxListTile).first;
    await tester.ensureVisible(checkboxFinder);
    await tester.pump();
    expect(tester.widget<CheckboxListTile>(checkboxFinder).value, isFalse);

    await tester.tap(checkboxFinder);
    await tester.pump();

    expect(
      game.employees.firstWhere((e) => e.id == employee.id).computerLinked,
      isTrue,
    );
    expect(tester.widget<CheckboxListTile>(checkboxFinder).value, isTrue);
  });
}
