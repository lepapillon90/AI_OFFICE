import 'package:ai_office/game/map/office_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a desk rectangle blocks its centre point', () {
    expect(
      OfficeLayout.blockers.any(
        (rect) => rect.contains(const Offset(416, 352)),
      ),
      isTrue,
    );
  });
}
