import 'package:ai_office/game/npc/ai_employee.dart';
import 'package:ai_office/game/npc/npc_component.dart';
import 'package:ai_office/game/npc/npc_status.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('지정된 좌석 위치에 배치된다', () {
    const employee = AiEmployee(
      id: 'ai-1',
      name: '테스트 직원',
      role: '개발자',
      provider: 'anthropic',
      workstationId: 'desk-1',
      status: NpcStatus.working,
    );

    final npc = NpcComponent(employee: employee, position: Vector2(416, 416));

    expect(npc.position, Vector2(416, 416));
    expect(npc.employee.displayStatus, '작업 중');
  });
}
