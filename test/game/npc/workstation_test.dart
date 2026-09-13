import 'package:ai_office/game/npc/workstation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Workstation', () {
    test('네 개의 고유한 좌석을 정의한다', () {
      final ids = Workstation.all.map((w) => w.id).toSet();
      expect(ids.length, Workstation.all.length);
      expect(Workstation.all.length, 4);
    });

    test('seatPosition은 책상 앞 의자 위치를 가리킨다', () {
      final workstation = Workstation.all.first;
      final seat = workstation.seatPosition;

      expect(seat.x, workstation.deskTopLeft.x + 32);
      expect(seat.y, workstation.deskTopLeft.y + 96);
    });
  });
}
