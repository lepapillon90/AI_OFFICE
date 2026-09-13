import 'package:ai_office/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the virtual office title', (tester) async {
    await tester.pumpWidget(const OfficeApp());

    expect(find.text('AI Office'), findsOneWidget);
  });
}
