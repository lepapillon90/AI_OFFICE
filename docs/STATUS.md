# 현재 상태와 다음 작업

## 완료

- Phase 1 Flutter Web + Flame 가상 오피스 데모
- 픽셀 오피스 맵, 캐릭터, 책상·의자·컴퓨터·휴게 구역
- WASD/방향키 이동, 카메라 추적, 벽·책상 충돌
- Chrome 시각 QA, 자동 테스트, 정적 분석
- Phase 2 오브젝트 상호작용 (`feature/phase2-interactions` 병합)
  - 컴퓨터 근접 시 `[E]` 안내, 팝업 열기/ESC·닫기로 복귀
- Phase 3 NPC와 AI 직원 표현 (`docs/PHASE3.md`, `docs/ROADMAP.md`)
  - `AiEmployee`/`NpcStatus` 데이터 모델, `Workstation` 좌석·컴퓨터 좌표
  - 3개 워크스테이션에 샘플 AI 직원 NPC를 고정 배치, 상태별 색상이 적용된 상태 라벨 표시
  - 마우스 휠 카메라 줌 인/아웃 (0.5배~2.5배)
  - 각 워크스테이션 컴퓨터가 해당 자리의 AI 직원과 연결: `[E]` 프롬프트와 팝업이 실제 직원 이름·역할·상태를 표시
  - 실제 AI 서버 연동과 Supabase 데이터는 아직 이연 범위

## 다음 작업

1. Supabase 인증·회사·직원 데이터 (Phase 4)
2. 실시간 멀티플레이와 채팅 (Phase 5)
3. AI 직원 연결 (실제 제공자 API로 NPC 상태 갱신, Phase 6)

## 검증 기록

- `flutter test`: 21개 통과
- `dart analyze`: 이상 없음
- `flutter analyze`: 이 PC의 Flutter 분석 서버 LSP 통신 오류로 진단 전 종료됨 (원인 분석: `docs/KNOWN_ISSUES.md`)
