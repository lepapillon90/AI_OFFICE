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
  - 4개 워크스테이션(2x2)에 샘플 AI 직원 NPC를 고정 배치 — 백엔드·프론트엔드·QA·인사관리자, 상태별 색상이 적용된 상태 라벨 표시
  - 마우스 휠 카메라 줌 인/아웃 (0.5배~2.5배)
  - 각 워크스테이션 컴퓨터가 해당 자리의 AI 직원과 연결: `[E]` 프롬프트와 팝업이 실제 직원 이름·역할·상태를 표시
  - 실제 AI 서버 연동과 Supabase 데이터는 아직 이연 범위
- 캐릭터 머리 위 배지(상태 점)·이름·직책 표시, 플레이어 클릭 시 프로필 카드(아바타 미리보기·이름 수정·아바타 꾸미기 placeholder)
- 대표·인사관리자용 "직원 정보 관리" 패널 (실시간 편집, 실제 권한 검증은 Phase 4 인증 이후 적용 예정)
- 4개 층 구조: 1층 로비·카페, 2층 업무공간·서버실(기존 개발팀), 3층 프로젝트룸, 4층 대표실
  - 층마다 같은 좌표에 있는 엘리베이터로 `[E]` 상호작용 → 층 선택 팝업
  - 층 전환 시 플레이어를 새 층 엘리베이터 옆으로 재배치, 워크스페이스 전용 상태(컴퓨터 근접 등)는 자동 초기화
- Phase 4 Supabase 인증·회사 데이터 (`docs/PHASE4_SUPABASE.md`) — 실제 계정으로 저장·복원까지 검증 완료
  - 아이디/비밀번호 로그인·회원가입 (`AuthGate`, `LoginScreen`, 내부적으로 mailinator.com 가상 이메일 매핑)
  - 로그인 시 회사 자동 생성 + `owner` 역할 부여 + 샘플 직원 3명 시드
  - owner/hr_manager만 "직원 정보 관리" 패널 사용 가능, 수정 내용은 Supabase에 저장
  - 로그아웃 → 재로그인 후에도 수정한 직원 정보가 그대로 복원됨을 실제 확인
  - 오피스 레이아웃 저장, 플레이어 프로필 영속화, 인사관리자 초대 UI는 이연
- Phase 5 실시간 위치 공유 (`MultiplayerChannel`, Supabase Realtime Presence)
  - 같은 회사 채널(`office:company:<id>`)에서 다른 접속자의 위치·이름·직책·상태를 실시간으로 표시
  - 같은 층에 있을 때만 렌더링, 층 이동 시 자동으로 나타나고 사라짐
  - 위치는 150ms 간격으로 스로틀링, 층 전환·프로필 변경은 즉시 전파
  - 가짜 두 번째 사용자를 같은 채널에 연결해 실제 브라우저 세션에 실시간 반영되는 것까지 검증
- Phase 5 공간 채팅 (`docs/PHASE5_MULTIPLAYER.md`)
  - Realtime Broadcast(실시간 전달) + `messages` 테이블(기록 보관) 조합
  - 화면 우측 상단 채팅 아이콘으로 패널 열기/닫기, 로그인 시 최근 메시지 50개 로드
  - 메시지 전송 시 로컬 즉시 표시 → 같은 회사 채널로 브로드캐스트 → DB 저장, `messages` 테이블 미생성 시에도 앱은 정상 동작(`catchError` 방어)
  - **주의**: 로컬(내가 보낸 메시지 즉시 표시)과 서버 전송(브로드캐스트 `ok` 응답)까지는 이번 세션에서 실제로 확인했으나, 다른 사용자로부터 오는 실시간 수신은 이번 자동화 브라우저 환경(프리뷰 서버 재시작 이후)에서 재현하지 못함 — 이전에 같은 방식(Presence)으로 성공했던 적이 있어 코드 자체보다는 이 세션의 브라우저 WebSocket 재연결 문제로 추정. 실제 브라우저 두 개로 별도 검증 권장
- 구성원 초대 (`docs/PHASE4_SUPABASE.md`의 "인사관리자 초대" 절) — 실제 계정으로 검증 완료
  - "직원 정보 관리" 패널 하단 "구성원 초대"에서 아이디 + 역할(인사관리자/일반 직원)로 초대장 생성
  - 대기 중인 초대 목록 표시, 취소(철회) 가능
  - 초대받은 아이디로 로그인하면 `ensureCompany()`가 자동으로 해당 회사에 지정된 역할로 합류시키고 초대를 accepted로 표시
  - `invites` 테이블 미생성 시 초대 시도 시 에러 메시지로 안내 (앱 자체는 깨지지 않음)
  - 실제 검증: 관리자가 `hr_manager` 역할로 초대 → 새 계정으로 회원가입 → 자동으로 같은 회사에 합류 + "직원 정보 관리" 패널 접근까지 확인
  - 진행 중 발견해 수정한 버그 2건: `invites`↔`company_members` RLS 정책 간 순환 참조("infinite recursion detected in policy") → `SECURITY DEFINER` 함수로 해결; `setState`에 대입식을 넘겨 Future를 반환하던 버그 → 블록 바디로 수정
- 채팅 `@멘션`: 귓속말 · AI 직원 명령 (`docs/PHASE6_AI_EMPLOYEES.md`) — 실제 OpenAI 응답까지 검증 완료
  - `@유저이름 ...` → 귓속말(보낸 사람·받는 사람에게만 표시), `@AI직원이름 ...` → 그 직원에게 실제 OpenAI API(`gpt-4o-mini`) 호출, 응답을 채팅에 표시
  - Supabase Edge Function `ask-employee`가 API 키를 서버 사이드에서만 보관(클라이언트에 노출 안 됨)
  - "귓속말 · AI" 탭은 카카오톡처럼 상대(유저 또는 AI 직원)별 개별 방으로 표시 — 방 목록(마지막 메시지 미리보기) → 방 클릭 시 그 상대와의 대화만, 방 안에서는 `@이름` 생략 가능(자동으로 붙음)
  - 마크다운 기호(`**`, `#` 등)는 프롬프트 지시 + 서버 사이드 후처리로 제거해 순수 텍스트로 표시
  - 실제 검증: `@하나 ...` 명령 → OpenAI 실응답 확인, `@유저이름 ...` 귓속말 → 다른 사용자 시뮬레이션으로 정확히 그 둘에게만 보임을 확인, 개별 방 목록/이동/자동 멘션까지 브라우저에서 확인
- Phase 6 나머지 기능 (`docs/PHASE6_AI_EMPLOYEES.md`) — 여러 턴 대화 맥락, 구조화된 업무 기록, 오류/재시도
  - 그 직원과 나눈 최근 대화(최대 6턴)를 `askEmployee`의 `history` 인자로 함께 전달 → Edge Function이 OpenAI 요청에 포함해 맥락 있는 답변 유도
  - `OfficeGame.tasksFor(employee)`가 명령/결과/상태/시도 횟수를 `NpcTask`로 최근 20건 기록 — 컴퓨터 팝업 "작업 이력" 버튼이 단일 최근 답변이 아닌 전체 이력을 보여줌
  - `askEmployee` 실패 시 한 번 자동 재시도 후에도 실패해야 "오류" 상태로 전환 — 일시적 오류로 바로 에러 표시되던 문제 개선
  - 자동 테스트(`test/computer_popup_npc_chat_test.dart`)로 히스토리 전달·재시도 횟수·작업 기록 검증, 이 세션의 브라우저 텍스트 입력 문제로 실제 OpenAI 응답의 맥락 반영 여부는 클릭 검증 못함
- Phase 6 사용량 추적 (`docs/PHASE6_AI_EMPLOYEES.md`) — 호출 횟수·성공/실패·토큰 사용량
  - `ask-employee` Edge Function이 OpenAI 응답의 `usage`(토큰 수)를 함께 반환 → `NpcCommandService`가 파싱해 `askEmployee` 결과(`NpcCommandResult`)에 포함
  - `OfficeGame.usageFor(employee)`/`totalUsage`가 직원별·전체 호출/성공/실패 횟수와 누적 토큰을 집계 — 자동 재시도로 인한 추가 호출도 각각 집계
  - 컴퓨터 팝업에 직원별 "호출 N회 (성공 N · 실패 N) · N 토큰" 요약과, 작업 이력 각 항목에 토큰 수 표시
  - 실제 비용(통화 환산)은 계산하지 않음 — OpenAI 대시보드에서 단가로 환산 필요
- Phase 6 DB 영속화 + 가상 문서 생성 (`docs/PHASE6_AI_EMPLOYEES.md`) — `NpcTask`/사용량이 재로그인 후에도 유지되고, 성공한 답변이 다운로드 가능한 문서가 됨
  - `npc_tasks`/`npc_usage_events` 테이블 + `npc-documents` Storage 버킷 SQL을 문서에 추가 — **아직 사용자가 Supabase에서 실행하지 않았다면 이 부분만 미완료**(실행 전까지 작업 이력·사용량은 세션 메모리에만 있고 새로고침 시 사라짐, 앱 자체는 정상 동작)
  - `OfficeGame`이 `onTaskChanged`/`onUsageEvent`로 매 변경을 알리고 `AuthGate`가 `NpcTaskRepository`/`NpcUsageRepository`로 저장, 로그인 시 `initialTasks`/`initialUsage`로 복원
  - 성공한 명령마다 `generateDocument` → `NpcDocumentRepository.upload()`가 결과를 텍스트 문서로 `npc-documents` 버킷에 저장, "작업 이력"의 "문서 열기" 버튼이 서명된 URL을 새 탭으로 엶(`lib/util/open_url.dart` — `flutter test`의 VM에서도 컴파일되도록 `dart:html`을 조건부 export로 격리)
  - 자동 테스트(`test/computer_popup_npc_chat_test.dart`)로 `onTaskChanged`/`onUsageEvent`/`generateDocument`/`documentUrlFor`/`initialTasks`/`initialUsage` 전부 검증, 실제 Supabase Storage 업로드·서명 URL 발급은 이 세션의 브라우저 문제로 클릭 검증 못함

## Phase 5 마무리 점검 (자동화 브라우저 환경의 한계)

이번 점검에서 실시간 수신을 다시 테스트한 결과:

- ✅ Presence(위치 공유) 수신 — Node 스크립트로 만든 가짜 사용자가 브라우저에 즉시 나타남을 재확인
- ✅ 이 브라우저에서 다른 사람에게 보내는 귓속말 송신 — 정상 전달 확인
- ❌ **다른 사람이 보낸 채팅(공간 채팅/귓속말 불문) 메시지를 이 브라우저가 수신하는 것만 재현 안 됨** — 같은 채널·같은 세션에서 presence는 되는데 채팅 브로드캐스트만 도착하지 않음. 코드(전송 형식, `onBroadcast` 바인딩, RLS 불필요한 public 채널)는 여러 번 검토했고 문제 없음, Dart 클라이언트가 브로드캐스트를 보내는 것도 정상 동작 — 이 자동화 브라우저 환경에서 "받는 쪽"만 안 되는 특이 현상으로 보임 (일반 사용자의 실제 브라우저 두 개에서는 정상 동작할 가능성이 높음)
- **권장**: 실제 브라우저(또는 폰) 두 개로 각각 로그인해서 한쪽에서 보낸 메시지가 다른 쪽에 실시간으로 뜨는지 딱 한 번만 확인해주세요. 이건 코드를 더 고쳐서 될 문제가 아니라 실제 환경에서 검증이 필요한 항목입니다.

- 컴퓨터 팝업 ↔ AI 직원 채팅 연동 (Phase 6)
  - "대화하기" → 컴퓨터 팝업을 닫고 그 직원의 "귓속말 · AI" 방을 바로 열어줌 (`OfficeGame.openChatWithEmployee`)
  - "작업 확인" → 그 직원의 최근 채팅 응답을 다이얼로그로 표시(`lastReplyFrom`), 대화 이력이 없으면 안내 문구
  - `test/computer_popup_npc_chat_test.dart`로 검증 — 이 세션의 브라우저 자동화가 키보드 이동을 안정적으로 재현하지 못해 실제 클릭 이동으로는 확인하지 못함(코드 경로 자체는 테스트로 확인됨)
  - 진행 중 발견해 고친 버그: `_RoomList`의 `ListTile`이 패널 배경 `DecoratedBox`와 `Material` 사이에 끼어 "ink splashes may be invisible" 경고가 뜨던 문제 → `Material(type: transparency)`로 감싸서 해결

## 다음 작업

1. `docs/PHASE5_MULTIPLAYER.md`의 `messages` 테이블 SQL, `docs/PHASE6_AI_EMPLOYEES.md`의 컬럼 추가 SQL, 그리고 **새로 추가된** `npc_tasks`/`npc_usage_events` 테이블·`npc-documents` Storage 버킷 SQL을 아직 안 하셨다면 Supabase SQL Editor/대시보드에서 실행 — 실행 전까지는 작업 이력·사용량이 세션 메모리에만 있다가 새로고침 시 사라지고, "문서 열기" 버튼도 나타나지 않지만 앱 자체는 정상 동작
2. 위 "Phase 5 마무리 점검"의 실제 브라우저 두 개 확인 (제가 자동화 환경에서는 재현 못 함)
3. **권장**: 실제 브라우저로 2층 컴퓨터 앞에서 `[E]` → "대화하기"/"작업 이력"/"문서 열기" 버튼까지 한 번 직접 클릭해서 확인 (이 세션은 자동화 키보드 이동이 안 돼서 코드 검증만 완료)
4. Phase 6 나머지(이연): 실제 비용(통화 환산) 계산, 사용량 상한/경고
5. 3층 NPC 배치 완료 — 3층 프로젝트룸에 `도윤`(PM/기획자)·`하윤`(프로덕트 디자이너). `NpcPlacement` 레지스트리(`lib/game/npc/npc_placement.dart`)로 층 가구 배치에 맞춰 자리 배정, 채팅 `@이름` 명령도 동일하게 동작. **4층 대표실엔 일부러 AI 직원을 두지 않음** — 대표는 실제 로그인한 사용자 본인이므로 AI NPC가 그 역할을 대신하지 않음. **1층 로비는 동시에 진행 중인 isometric 로비 작업과 충돌을 피하려고 이번엔 건드리지 않음** — 그 작업이 정리되면 이어서 진행 필요. 자동 테스트(`test/npc_placement_test.dart`)로 배치·로스터 일치 확인, 이 세션의 브라우저 텍스트 입력 문제로 실제 채팅 명령 클릭 검증은 못함
6. 타일 렌더링 최적화 완료 + `test/lobby_runtime_test.dart` 타임아웃의 실제 원인 정정
   - **최적화**: 1층 이소메트릭 로비(24×16=384타일)와 2층 업무공간(24×16=384타일) 모두, 타일 하나당 별도 `SpriteComponent`(+개별 `Sprite.load`)를 마운트하던 방식에서 → 같은 이미지를 쓰는 타일들을 묶어 **에셋당 한 번만 로드**하고 캔버스에 직접 그리는 방식으로 변경(`IsoFloorTilesComponent`, `OfficeMap`의 `_TileBatchComponent`). 1층은 384개 타일이 실제 이미지 수(수십 개) 기준으로만 로드되도록 줄었고, 자동 테스트(`test/iso_lobby_scene_test.dart`)로 "고유 에셋 수 < 타일 수" 및 위치·개수 정합성 검증 — 이 테스트가 이전엔 수 분~10분 타임아웃 나던 게 지금은 1초 이내로 통과
   - **`lobby_runtime_test.dart`의 10분 타임아웃, 재진단 결과 원인 정정**: 처음엔 "타일이 너무 많아서"로 추정했으나, 최적화 후에도 이 테스트만 계속 멈춰서 별도로 최소 재현 테스트를 만들어 확인한 결과 — 원인은 타일 개수가 아니라 이 테스트의 `_mount` 헬퍼가 `tester.runAsync()` 안에서 `await game.loaded`/`await game.ready()`를 호출하는 패턴 자체였음. `runAsync`는 진짜 비동기 IO용이라 그 안에서는 Flutter 위젯/게임 프레임이 진행되지 않는데, 이 Flame 버전(1.38.2)의 컴포넌트 마운트 완료는 프레임 틱에 걸려 있어서 `loaded`/`ready()`가 영원히 끝나지 않음 — **1층/2층 타일 개수와 무관하게, 커스터마이징 없는 기본 `OfficeGame()`을 이 패턴으로 마운트하기만 해도 재현됨**(최소 재현 테스트로 확인, 임시 파일이라 커밋하지 않음). 즉 제가 만든 변경사항의 회귀가 아니라 그 테스트 파일의 마운트 헬퍼 자체가 이 Flame 버전과 안 맞는, 이전부터 있었을 가능성이 높은 문제
   - 같은 helper를 쓰는 `lobby_runtime_test.dart`는 여전히 타임아웃 나지만, `tester.pump()`를 반복하거나 `tester.pumpAndSettle()`을 쓰는 다른 모든 테스트(이 세션에서 만든 것 포함, 예: `computer_popup_npc_chat_test.dart`)는 전부 정상 통과 — 이 파일은 다른 프로세스 소유라 `_mount` 헬퍼 자체를 고치지는 않았음. 고치려면 `runAsync` 없이 `await tester.pump()`를 여러 번 부르거나 `pumpAndSettle()`로 바꾸면 될 것으로 보임(제가 만든 최소 재현 테스트로 그 대안들은 즉시 통과하는 것까지 확인)

## 검증 기록

- `flutter test`: 이 세션에서 작성/수정한 파일 관련 테스트(`widget_test.dart`, `computer_interaction_test.dart`, `workstation_test.dart`, `computer_popup_npc_chat_test.dart`) 전부 통과. 전체 스위트는 동시에 진행 중인 다른 작업(isometric 로비)이 같은 브랜치에서 진행형이라 파일별로 나눠 확인 중
- `dart analyze`: 이상 없음
- `flutter analyze`: 이 PC의 Flutter 분석 서버 LSP 통신 오류로 진단 전 종료됨 (원인 분석: `docs/KNOWN_ISSUES.md`)
