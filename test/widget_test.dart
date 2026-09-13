import 'package:ai_office/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the virtual office title', (tester) async {
    await tester.pumpWidget(const OfficeApp());

    expect(find.text('AI Office'), findsOneWidget);
  });

  testWidgets('loads the player sprite asset', (tester) async {
    await tester.pumpWidget(const OfficeApp());
    await tester.pumpWidget(
      const MaterialApp(
        home: Image(image: AssetImage('assets/images/characters/office_worker.png')),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
