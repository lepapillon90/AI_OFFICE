import 'package:ai_office/game/npc/ai_employee.dart';
import 'package:ai_office/game/npc/npc_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NpcStatus', () {
    test('각 상태의 한국어 표시 문구를 반환한다', () {
      expect(NpcStatus.idle.displayLabel, '대기 중');
      expect(NpcStatus.working.displayLabel, '작업 중');
      expect(NpcStatus.meeting.displayLabel, '회의 중');
      expect(NpcStatus.error.displayLabel, '오류');
      expect(NpcStatus.offline.displayLabel, '퇴근');
    });
  });

  group('AiEmployee', () {
    const employee = AiEmployee(
      id: 'ai-1',
      name: '테스트 직원',
      role: '개발자',
      provider: 'anthropic',
      workstationId: 'desk-1',
      status: NpcStatus.idle,
    );

    test('생성 시 모든 필드를 보존한다', () {
      expect(employee.id, 'ai-1');
      expect(employee.name, '테스트 직원');
      expect(employee.role, '개발자');
      expect(employee.provider, 'anthropic');
      expect(employee.workstationId, 'desk-1');
      expect(employee.status, NpcStatus.idle);
    });

    test('copyWith은 원본을 바꾸지 않고 새 상태 모델을 반환한다', () {
      final updated = employee.copyWith(status: NpcStatus.working);

      expect(updated.status, NpcStatus.working);
      expect(employee.status, NpcStatus.idle);
      expect(updated.id, employee.id);
      expect(updated.name, employee.name);
    });

    test('displayStatus는 변경된 상태와 일치한다', () {
      final updated = employee.copyWith(status: NpcStatus.working);

      expect(updated.displayStatus, '작업 중');
      expect(employee.displayStatus, '대기 중');
    });
  });
}
