import 'package:ai_office/game/floors/floor.dart';
import 'package:ai_office/game/npc/npc_placement.dart';
import 'package:ai_office/game/npc/sample_employees.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('3층/4층 NPC 배치가 각 층의 가구와 일치한다', () {
    expect(NpcPlacement.forFloor(Floor.projectRoom).map((p) => p.id),
        ['project-desk-1', 'project-desk-2']);
    expect(NpcPlacement.forFloor(Floor.executive).map((p) => p.id),
        ['executive-desk']);
    // 2층 desk grid isn't NpcPlacement's concern.
    expect(NpcPlacement.forFloor(Floor.workspace), isEmpty);
    expect(NpcPlacement.forFloor(Floor.lobby), isEmpty);
  });

  test('샘플 직원 로스터에 3층/4층 직원이 배치와 일치하게 포함되어 있다', () {
    final byWorkstation = {
      for (final e in sampleEmployees) e.workstationId: e,
    };

    for (final placement in NpcPlacement.all) {
      expect(byWorkstation.containsKey(placement.id), isTrue,
          reason: '${placement.id}에 배정된 직원이 없습니다');
    }
  });
}
