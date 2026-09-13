# 현재 상태와 다음 작업

## 완료

- Phase 1 Flutter Web + Flame 가상 오피스 데모
- 픽셀 오피스 맵, 캐릭터, 책상·의자·컴퓨터·휴게 구역
- WASD/방향키 이동, 카메라 추적, 벽·책상 충돌
- Chrome 시각 QA, 자동 테스트, 정적 분석
- Phase 3 NPC 자리 배정과 상태 표시 (`docs/PHASE3.md`)
  - `AiEmployee`/`NpcStatus` 데이터 모델, `Workstation` 좌석 좌표
  - 3개 워크스테이션에 샘플 AI 직원 NPC를 고정 배치하고 상태 라벨(`TextComponent`) 표시
  - 실제 AI 서버 연동과 Supabase 데이터는 아직 이연 범위

## 다음 작업

1. 오브젝트 접근과 사용하기 UI (`phase2-interactions` 워크트리에서 진행 중)
2. Supabase 인증·회사·직원 데이터
3. 실시간 멀티플레이와 채팅
4. AI 직원 연결 (실제 제공자 API로 NPC 상태 갱신)

## 검증 기록

- `flutter test`: 15개 통과
- `dart analyze`: 이상 없음
- `flutter analyze`: 이 PC의 Flutter 분석 서버 LSP 통신 오류로 진단 전 종료됨 (원인 분석: `docs/KNOWN_ISSUES.md`)
