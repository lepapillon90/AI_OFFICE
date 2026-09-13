# AI 오피스 — Phase 3 NPC 자리 배정과 상태 표시

## 목표

각 워크스테이션에 AI 직원 NPC를 고정 배치하고, 화면에서 각 NPC의 현재 상태(대기 중/작업 중/회의 중/오류/퇴근)를 텍스트 라벨로 확인할 수 있게 한다.

## 범위

- `lib/game/npc/workstation.dart` — 기존 `OfficeLayout`의 책상 좌표를 좌석(id, position)으로 정의
- `lib/game/npc/npc_component.dart` — `AiEmployee`를 렌더링하는 Flame `PositionComponent`
  - 기존 `characters/office_worker.png` 스프라이트 재사용 (정지 상태, 별도 이동 없음)
  - 스프라이트 위에 상태 라벨(`displayStatus`)을 `TextComponent`로 표시
- `lib/game/office_game.dart` — 샘플 `AiEmployee` 목록을 좌석에 배치해 `world`에 추가
  - 플레이어 이동·충돌 로직(`OfficePlayer`)은 변경하지 않는다
- 테스트: NPC 컴포넌트가 올바른 위치에 배치되는지, 상태 라벨 텍스트가 `displayStatus`와 일치하는지 검증

## 제외 범위 (다음 단계로 이연)

- Supabase 인증·회사·직원 데이터 연동
- 실시간 멀티플레이와 채팅
- 실제 AI 서버(제공자 API) 연결 및 상태 갱신
- 오브젝트 사용 UI/상호작용 (Phase 2, `phase2-interactions` 워크트리에서 별도 진행 중이므로 본 작업에서 건드리지 않음)
- 새 NPC 전용 아트 에셋 제작 (기존 `office_worker.png` 재사용으로 대체)

## 건드리지 않는 파일

Phase 2 작업과의 충돌을 피하기 위해 아래는 수정하지 않는다.

```text
lib/game/player/
lib/game/interactions/
lib/screens/
test/widget_test.dart
test/computer_interaction_test.dart
pubspec.yaml (에셋 추가가 꼭 필요하면 최소한으로만 변경)
docs/ROADMAP.md
```

## 완료 기준

- 웹 앱 실행 시 3개 워크스테이션 각각에 AI 직원 NPC가 보이고, 상태 라벨이 표시된다.
- `flutter test`, `dart analyze` 통과.
- `docs/STATUS.md`의 다음 작업 2번 항목("NPC 자리 배정과 상태 표시")을 완료로 갱신한다.
