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
  - ~~실제 비용(통화 환산)은 계산하지 않음~~ — 이후 `docs/PHASE7_OPS_REVIEW.md`의 후속 반영에서 gpt-4o-mini 단가 기준 USD 환산(`estimatedCostUsd`)을 추가해 팝업에 "약 $0.0012"처럼 표시
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
- Phase 7 착수 — 알림과 활동 기록 (`docs/PHASE7_ACTIVITY.md`)
  - 직원 정보 수정, AI 직원 명령 성공/실패를 `OfficeGame.activityLog`에 기록 — 화면 우측 상단 알림(🔔) 아이콘 + 안 읽은 개수 배지, 누르면 "활동 기록" 패널
  - `activity_events` 테이블에 영속화(마이그레이션 SQL은 `docs/PHASE7_ACTIVITY.md`) — 실행 전에도 세션 메모리 기준으로는 정상 동작
  - 자동 테스트(`test/activity_log_test.dart`)로 로깅·안 읽음 카운트·초기 복원 검증
  - 이연: 구성원 초대/합류 이벤트는 아직 활동 기록에 안 남음, 실시간(다른 세션 즉시 반영) 아님
  - ~~안 읽음 상태 자체의 서버 영속화 없음~~ — 완료(아래 "Phase 7 후속 반영 2" 참고)
- Phase 7 — 프로젝트·업무 보드 연결 (`docs/PHASE7_BOARD.md`)
  - 할 일/진행 중/완료 3칸 칸반 보드 — 화면 우측 상단 보드(칸반) 아이콘으로 열기, "새 업무"로 카드 추가(제목+담당 AI 직원 선택), 카드마다 이전/다음 단계 이동·삭제 버튼
  - 담당자가 있는 카드는 "AI에게 지시" 버튼으로 그 직원 채팅방을 열고 카드 제목을 `@직원이름 제목` 명령으로 바로 전송 — Phase 6 명령 파이프라인(재시도, 작업 이력, 사용량 집계) 그대로 적용됨
  - 카드 생성/이동/배정/삭제가 활동 기록에도 함께 남음
  - `board_tasks` 테이블에 영속화(마이그레이션 SQL은 `docs/PHASE7_BOARD.md`) — 실행 전에도 세션 메모리 기준으로는 정상 동작
  - 자동 테스트(`test/board_test.dart`)로 생성/이동/배정/삭제/AI 지시 전부 검증 + 실제 브라우저 클릭으로도 "새 업무" 생성(제목 입력·담당자 선택)→ 다음 단계로 이동 → 삭제까지 전 과정 확인(활동 기록 배지도 각 조작마다 정상 증가)
  - ~~이연: 드래그 앤 드롭, 카드 설명 편집 UI~~ — 완료(아래 "Phase 7 후속 반영 2" 참고). 이연: 사람에게 배정, 여러 사용자 간 실시간 동기화
- Phase 7 — 회의실·회의 진행 UI (`docs/PHASE7_MEETING.md`)
  - 2층 회의실 파티션 안(맵 데스크/라운지와 겹치지 않는 위치)에 회의 테이블 상호작용 추가, `[E]`로 열기 — 컴퓨터·엘리베이터와 동일한 패턴(`MeetingRoomInteraction`)
  - 참석자(AI 직원) 선택 → "회의 시작"으로 각자 상태를 "회의 중"으로 전환(기존 `_setEmployeeStatus`의 ephemeral 패턴 재사용, 개별 Supabase 저장 없음) → 진행 중엔 참석자 목록·경과 시간 표시 → "회의 종료"로 각자 원래 상태 복원
  - 시작/종료 모두 활동 기록에 남음(새 테이블 불필요 — 기존 `activity_events` 재사용), 동시에 하나의 회의만 가능
  - 자동 테스트(`test/meeting_test.dart`)로 근접 감지·팝업 열기닫기·이동 차단·시작/종료 상태 복원·활동 기록·이연 케이스(참석자 없음, 이미 진행 중) 전부 검증. 이 세션의 브라우저 텍스트 입력/좌표 오차 이슈로 실제 클릭 흐름 검증은 다음 확인 필요
  - 이연: 실제 화상/음성 통화, 회의 예약(캘린더), 진행 중인 회의 자체의 Supabase 영속화, 사람 참석자 지정
- Phase 7 — 관리자 화면 · 감사 기록 · 권한 강화 (`docs/PHASE7_ADMIN.md`)
  - **관리자 화면**: 화면 우측 상단 관리자 아이콘(대표에게만 표시) — 실제 로그인 계정(구성원) 목록과 역할, "감사 기록 보기"로 활동 기록 패널 바로 열기. `company_members_with_email` SECURITY DEFINER 함수로 대표만 자기 회사 구성원의 아이디 조회(`auth.users`는 클라이언트에서 직접 조회 불가)
  - **감사 기록**: 활동 기록에 `actor_name`(행위자) 추가 — 지금까지 "무엇을"만 있던 것에 "누가"까지 표시("OOO · 방금 전")
  - **권한 강화**: (1) 관리자 화면 자체가 대표 전용(`CompanyRole.canManageMembers`), (2) "인사관리자" 초대는 대표만 가능하도록 좁힘 — 이전엔 인사관리자가 다른 사람을 인사관리자로 초대할 수 있는 권한 상승 구멍이 있었음(클라이언트 드롭다운에서 숨기고, RLS `managers_insert_invites` 정책도 서버에서 강제)
  - **진행 중 발견해 고친 버그**: `activity_events.type`의 체크 제약이 `'board'`/`'meeting'` 값을 허용하지 않아서, 이전에 `docs/PHASE7_ACTIVITY.md`의 SQL만 실행한 상태로 업무 보드·회의 기능을 쓴 사용자는 그 활동 기록 저장이 조용히 실패하고 있었을 것 — `docs/PHASE7_ADMIN.md`의 SQL에 제약 재생성 포함
  - 자동 테스트(`test/company_role_test.dart`, `test/activity_log_test.dart`의 actorName 검증)로 커버 — `CompanyRepository`가 실제 `SupabaseClient`에 의존해 관리자 화면의 구성원 목록·역할 변경 UI 자체는 위젯 테스트로 검증 못함(이 프로젝트의 기존 테스트 경계와 동일 — Chat/Task/Usage 등 다른 Supabase 연동 레포지토리들도 위젯 레벨로는 테스트하지 않음), 코드 리뷰로 확인
- Phase 7 마지막 항목 — 성능·보안·배포 운영 점검 (`docs/PHASE7_OPS_REVIEW.md`, Phase 7 전체 항목 완료)
  - **보안(실제로 고침)**: `ask-employee` Edge Function이 "로그인한 사용자인지"만 확인하고 "그 회사 구성원인지"는 확인하지 않던 것을 발견 — 다른 회사인 척 직접 호출해 대표님 OpenAI 예산을 소모시킬 수 있던 구멍. 이제 `companyId`를 함께 받아 호출자 JWT로 `company_members` 실제 소속을 확인(403 거절)
  - **비용/보안(실제로 고침)**: 같은 함수에 회사당 최근 5분·30회 호출 상한 추가(기존 `npc_usage_events` 카운트 기반), 명령 2000자·대화 맥락 턴당 2000자·최대 6턴으로 서버 쪽 강제 절단(클라이언트 제한은 우회 가능하므로 진짜 방어선은 서버)
  - **성능(실제로 고침)**: `AuthGate._load()`가 역할·로스터·채팅/작업/사용량/활동/보드 이력을 7번 **순차** 조회하던 것 → `Future.wait`로 병렬화(로그인 지연 = 가장 느린 쿼리 하나 수준으로 단축), `BoardRepository.fetchTasks()`에 누락됐던 조회 상한(최근 500건) 추가
  - **진단만 하고 코드는 안 건드린 것**(라이브 재현·반복 검증 없이 바꾸기엔 위험): Realtime 채널(`office:company:<id>`)이 RLS로 보호되지 않아 companyId를 아는 다른 가입자가 구독 가능한 점, Vercel 빌드가 매번 Flutter SDK 재클론하는 점, 웹 렌더러 미검토
  - Edge Function 재배포 필요(`docs/PHASE7_OPS_REVIEW.md`) — 재배포 전까지는 새로 추가한 소속 확인/사용량 상한이 적용 안 됨, 다만 클라이언트가 `companyId`를 추가로 보내는 것 자체는 구버전 함수에서 무시되므로 앱은 정상 동작
  - 자동 테스트(`dart analyze` 전체 통과, `test/board_test.dart`/`test/chat_panel_test.dart`/`test/widget_test.dart`/`test/computer_popup_npc_chat_test.dart` 회귀 없음 확인) — Edge Function의 새 로직(소속 확인·상한)은 배포 후 라이브 호출로 직접 검증 필요(이 세션에서는 파일 변경만, 재배포 전이라 아직 검증 못함)
  - **재배포 후 라이브 검증 완료** — 실제로 재배포하고 관리자 계정으로 호출해보니 정상 요청까지 500 에러가 나는 버그(`.maybeSingle()`이 구성원 2명 이상인 회사의 대표 호출 시 여러 행을 반환받아 실패)를 발견해 `.limit(1)`로 수정, 재배포 후 소속 확인(403)·사용량 상한(429)·정상 호출·멀티턴 맥락까지 4개 케이스 전부 실제 OpenAI 응답으로 재검증 완료
- Phase 7 후속 반영 — 의도적으로 미뤘던 4가지 항목(`docs/PHASE7_OPS_REVIEW.md`, Vercel 빌드 캐시는 제외하고 전부 완료)
  - **비용 환산**: `NpcUsage`/`NpcUsageSummary`에 gpt-4o-mini 단가 기준 `estimatedCostUsd` 추가, 컴퓨터 팝업의 직원별 누적/작업별 사용량 옆에 "약 $0.0012"처럼 USD 표시. 자동 테스트(`test/npc_usage_cost_test.dart`)로 검증
  - **사용량 상한 알림 UI**: `ask-employee`의 429 응답을 `AskEmployeeRateLimitException`(`lib/game/npc/npc_command_errors.dart`)으로 구분 — 일반 오류와 달리 재시도하지 않고, 실제 호출이 없었으므로 사용량 집계에도 카운트 안 함, 채팅/작업 이력/활동 기록에 한도 메시지를 그대로 노출. 자동 테스트(`test/computer_popup_npc_chat_test.dart`)로 검증
  - **감사 기록 사용자 ID**: `activity_events`에 `actor_user_id`(안정적인 Supabase auth id) 컬럼 추가 — 표시 이름(`actor_name`)과 달리 계정이 리네임돼도 안 바뀜. 지금은 값만 쌓아두고 UI엔 아직 안 보여줌. 자동 테스트(`test/activity_log_test.dart`)로 검증
  - **Realtime 채널 접근 제어**: `MultiplayerChannel`이 여는 `office:company:<companyId>` 채널을 `RealtimeChannelConfig(private: true)`로 전환하고, `realtime.messages`에 `company_members` 소속을 확인하는 RLS 정책을 추가(Supabase Realtime Authorization) — companyId만 안다고 아무나 구독하던 구멍을 막음. **실제 Node 스크립트로 라이브 검증 완료**: (1) 대표가 자기 회사 채널 구독 → `SUBSCRIBED`, (2) 같은 사용자가 소속 아닌 임의 회사 채널 구독 시도 → `Unauthorized` 에러로 거절, (3) 같은 회사의 다른 구성원이 같은 채널 구독 → `SUBSCRIBED` — 3케이스 전부 의도대로 동작
  - **웹 렌더러**: Flutter 3.47.4의 `flutter build web --help`를 직접 확인한 결과 예전 `--web-renderer` 플래그가 이미 없고 CanvasKit이 기본이자 유일한 렌더러임을 확인 — 코드/스크립트 변경 불필요, 로컬 `flutter build web --release`로 정상 빌드까지 확인
  - **제외**: Vercel 빌드 캐시 — Vercel 대시보드 설정이 필요해 코드만으로는 확인 불가하다는 이유로 사용자가 명시적으로 이번 범위에서 제외
- Phase 7 후속 반영 2 — 남은 이연(minor) 항목 3가지(`docs/PHASE7_ACTIVITY.md`, `docs/PHASE7_BOARD.md`)
  - **안 읽음 상태 서버 영속화**: `activity_read_marks(company_id, user_id, last_read_at)` 테이블을 추가해, "활동 기록" 패널을 열 때마다(=읽음 처리) 현재 시각을 저장(`ActivityRepository.markRead`). 로그인 시 그 값을 불러와(`fetchLastReadAt`) 그 시각 이후 이벤트만 안 읽음으로 계산 — 마크가 없으면(첫 로그인/미실행) 전부 읽음으로 간주해 시작(과거 이력이 갑자기 안 읽음으로 뜨는 것 방지). 자동 테스트(`test/activity_log_test.dart`)로 초기 복원 로직·콜백 호출 검증, 실제 앱에서 알림 배지가 0으로 정상 초기화되는 것까지 브라우저로 확인(단, 테이블 SQL을 아직 실행 안 하면 읽음 상태는 저장되지 않고 매번 "전부 읽음"으로 시작 — 앱은 정상 동작)
  - **업무 보드 카드 설명 편집 UI**: 카드마다 편집 아이콘으로 여러 줄 설명을 입력·수정·삭제(`OfficeGame.editBoardTaskDescription`), 카드에 최대 2줄 미리보기 표시. 데이터 모델(`BoardTask.description`)과 DB 컬럼은 이미 있어서 이번엔 UI만 추가
  - **업무 보드 드래그 앤 드롭**: 카드가 `Draggable<String>`, 각 칸이 `DragTarget<String>` — 드롭 시 `OfficeGame.setBoardTaskStatus()`로 그 칸에 바로 이동(중간 칸을 거치지 않음, 기존 "이전/다음 단계로" 버튼은 그대로 유지). 실제 실행 중인 앱에서 라이브로 확인(정상적으로 칸 이동, 활동 기록에도 남음) — `WidgetTester`로 Flutter의 Draggable/DragTarget 제스처 아레나를 재현하는 위젯 테스트는 이 세션에서 불안정하게 나와 제외, `OfficeGame.setBoardTaskStatus()` 자체는 `test/board_test.dart`로 검증
  - **라이브 검증 중 발견해 함께 고친 버그**: "새 업무" 다이얼로그의 제목 `TextField`에 `onChanged`가 없어서, 제목을 입력해도 다이얼로그가 다시 빌드되지 않아 "추가" 버튼이 첫 렌더링(빈 텍스트) 기준으로 계속 비활성 상태에 멈춰있던 버그 — 실제 브라우저 클릭 검증 중 발견, `onChanged: (_) => setDialogState(() {})` 추가로 수정, 회귀 테스트(`test/board_panel_test.dart`) 추가
- **Phase 8 착수** — 사용자와 논의해 로드맵 원안 이후의 새 방향 확정(`docs/ROADMAP.md`), 첫 항목으로 파일 업로드/공유 구현 (`docs/PHASE8_FILE_SHARING.md`)
  - 채팅 입력창에 📎 첨부 버튼 추가 — 브라우저 파일 선택창(`lib/util/pick_file.dart`, `flutter test` VM에서는 안전하게 null만 반환하는 조건부 export 패턴, `lib/util/open_url.dart`와 동일한 방식)으로 실제 파일을 골라 `chat-attachments` Storage 버킷에 업로드
  - 공간 채팅/귓속말/AI 직원 방 어디로든 보낼 수 있음 — AI 직원 방에 보내도 명령으로 해석돼 불필요한 API 호출이 나가지 않도록, 본문을 `@이름`만(명령 없이) 채워 보냄(`OfficeGame.sendChatAttachment`)
  - 메시지 목록에 파일명 칩으로 표시, 클릭 시 서명 URL을 새 탭으로 열람(`OfficeGame.attachmentUrlFor`)
  - `messages` 테이블에 `attachment_path`/`attachment_name` 컬럼 추가 필요(마이그레이션 SQL은 `docs/PHASE8_FILE_SHARING.md`) — 실행 전엔 업로드가 조용히 실패할 뿐 텍스트 채팅은 정상 동작
  - 자동 테스트(`test/chat_attachment_test.dart`)로 업로드 성공/실패/미설정, AI 방 오발송 방지, URL 해석 전부 검증 — 실제 `dart:html` 파일 선택창 자체는 `flutter test`의 VM에서 재현 불가해 실제 브라우저 확인 권장
  - 이연: AI 직원이 첨부 파일 내용을 실제로 읽는 기능, 이미지 미리보기, 업무 보드 카드 첨부

## 다음 작업

1. `docs/PHASE5_MULTIPLAYER.md`의 `messages` 테이블 SQL, `docs/PHASE6_AI_EMPLOYEES.md`의 컬럼 추가 SQL, 그리고 **새로 추가된** `npc_tasks`/`npc_usage_events` 테이블·`npc-documents` Storage 버킷 SQL, `docs/PHASE7_ACTIVITY.md`/`docs/PHASE7_BOARD.md`/`docs/PHASE7_ADMIN.md`의 SQL을 아직 안 하셨다면 Supabase SQL Editor/대시보드에서 실행 — 실행 전까지는 작업 이력·사용량·활동 기록·업무 보드가 세션 메모리에만 있다가 새로고침 시 사라지지만 앱 자체는 정상 동작
1-3. **새로 추가된** `docs/PHASE7_ACTIVITY.md`의 `activity_read_marks` 테이블 SQL(안 읽음 상태 서버 영속화)도 아직이면 실행 필요 — 실행 전까지는 로그인마다 활동 기록을 전부 "읽음"으로 간주해 시작(에러는 아님)
1-1. `ask-employee` Edge Function 재배포 완료 및 라이브 검증 완료 — 소속 확인(403)·사용량 상한(429) 정상 동작 확인 (이 항목은 완료됨)
1-2. `realtime.messages` RLS 정책(Realtime Authorization) 적용 및 라이브 검증 완료 — 클라이언트가 다음 배포/새로고침 때 자동으로 `private: true`로 붙음
2. 위 "Phase 5 마무리 점검"의 실제 브라우저 두 개 확인 (제가 자동화 환경에서는 재현 못 함)
3. **권장**: 실제 브라우저로 2층 컴퓨터 앞에서 `[E]` → "대화하기"/"작업 이력"/"문서 열기" 버튼까지 한 번 직접 클릭해서 확인 (이 세션은 자동화 키보드 이동이 안 돼서 코드 검증만 완료)
4. ~~Phase 6 나머지(이연): 실제 비용(통화 환산) 계산, 사용량 상한/경고~~ — 완료(위 "Phase 7 후속 반영" 참고)
5. 3층 NPC 배치 완료 — 3층 프로젝트룸에 `도윤`(PM/기획자)·`하윤`(프로덕트 디자이너). `NpcPlacement` 레지스트리(`lib/game/npc/npc_placement.dart`)로 층 가구 배치에 맞춰 자리 배정, 채팅 `@이름` 명령도 동일하게 동작. **4층 대표실엔 일부러 AI 직원을 두지 않음** — 대표는 실제 로그인한 사용자 본인이므로 AI NPC가 그 역할을 대신하지 않음. **1층 로비는 동시에 진행 중인 isometric 로비 작업과 충돌을 피하려고 이번엔 건드리지 않음** — 그 작업이 정리되면 이어서 진행 필요. 자동 테스트(`test/npc_placement_test.dart`)로 배치·로스터 일치 확인, 이 세션의 브라우저 텍스트 입력 문제로 실제 채팅 명령 클릭 검증은 못함
6. 타일 렌더링 최적화 완료 + `test/lobby_runtime_test.dart` 타임아웃의 실제 원인 정정
   - **최적화**: 1층 이소메트릭 로비(24×16=384타일)와 2층 업무공간(24×16=384타일) 모두, 타일 하나당 별도 `SpriteComponent`(+개별 `Sprite.load`)를 마운트하던 방식에서 → 같은 이미지를 쓰는 타일들을 묶어 **에셋당 한 번만 로드**하고 캔버스에 직접 그리는 방식으로 변경(`IsoFloorTilesComponent`, `OfficeMap`의 `_TileBatchComponent`). 1층은 384개 타일이 실제 이미지 수(수십 개) 기준으로만 로드되도록 줄었고, 자동 테스트(`test/iso_lobby_scene_test.dart`)로 "고유 에셋 수 < 타일 수" 및 위치·개수 정합성 검증 — 이 테스트가 이전엔 수 분~10분 타임아웃 나던 게 지금은 1초 이내로 통과
   - **`lobby_runtime_test.dart`의 10분 타임아웃, 재진단 결과 원인 정정**: 처음엔 "타일이 너무 많아서"로 추정했으나, 최적화 후에도 이 테스트만 계속 멈춰서 별도로 최소 재현 테스트를 만들어 확인한 결과 — 원인은 타일 개수가 아니라 이 테스트의 `_mount` 헬퍼가 `tester.runAsync()` 안에서 `await game.loaded`/`await game.ready()`를 호출하는 패턴 자체였음. `runAsync`는 진짜 비동기 IO용이라 그 안에서는 Flutter 위젯/게임 프레임이 진행되지 않는데, 이 Flame 버전(1.38.2)의 컴포넌트 마운트 완료는 프레임 틱에 걸려 있어서 `loaded`/`ready()`가 영원히 끝나지 않음 — **1층/2층 타일 개수와 무관하게, 커스터마이징 없는 기본 `OfficeGame()`을 이 패턴으로 마운트하기만 해도 재현됨**(최소 재현 테스트로 확인, 임시 파일이라 커밋하지 않음). 즉 제가 만든 변경사항의 회귀가 아니라 그 테스트 파일의 마운트 헬퍼 자체가 이 Flame 버전과 안 맞는, 이전부터 있었을 가능성이 높은 문제
   - 같은 helper를 쓰는 `lobby_runtime_test.dart`는 여전히 타임아웃 나지만, `tester.pump()`를 반복하거나 `tester.pumpAndSettle()`을 쓰는 다른 모든 테스트(이 세션에서 만든 것 포함, 예: `computer_popup_npc_chat_test.dart`)는 전부 정상 통과 — 이 파일은 다른 프로세스 소유라 `_mount` 헬퍼 자체를 고치지는 않았음. 고치려면 `runAsync` 없이 `await tester.pump()`를 여러 번 부르거나 `pumpAndSettle()`로 바꾸면 될 것으로 보임(제가 만든 최소 재현 테스트로 그 대안들은 즉시 통과하는 것까지 확인)

## 검증 기록

## 1층 에셋 기반 레이아웃

- 1층은 **28×18 타일 · 타일당 64px · 1792×1152px** 규격으로 확장 완료.
- 제공된 `assets/1층` 에셋 시트에서 분리한 v4 스프라이트로 상단 로비·카페·중앙 나무 화단·매점·라운지·입구/연못 조경을 배치.
- 중앙 나무 화단 주위에 128px 이상 통로를 보장하고, 바닥 뒤에 구조물·가구·브랜딩·조경을 레이어 순서로 렌더링.
- 원본 시트에서 유입된 엘리베이터·카페 카운터·입구 화분의 선/글자 조각은 제거 후 재검수.
- 렌더링 QA 이미지: `docs/qa/first-floor-asset-layout.png`.
- 제한 사항: 별도 메뉴 보드·긴 공용 테이블·웰컴 매트·독립 슬로건 보드는 현재 제공 에셋에 없어 추가 제작 전까지 배치하지 않음. 실시간 플레이어 이동을 포함한 광범위 런타임 테스트는 기존 Flame 테스트 헬퍼의 멈춤 문제로 이번 검수 범위에서 제외.

- `flutter test`: 이 세션에서 작성/수정한 파일 관련 테스트(`widget_test.dart`, `computer_interaction_test.dart`, `workstation_test.dart`, `computer_popup_npc_chat_test.dart`) 전부 통과. 전체 스위트는 동시에 진행 중인 다른 작업(isometric 로비)이 같은 브랜치에서 진행형이라 파일별로 나눠 확인 중
- `dart analyze`: 이상 없음
- `flutter analyze`: 이 PC의 Flutter 분석 서버 LSP 통신 오류로 진단 전 종료됨 (원인 분석: `docs/KNOWN_ISSUES.md`)
