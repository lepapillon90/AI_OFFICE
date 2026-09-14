# Phase 8 — 회사 컴퓨터 원격 명령 (터미널 열기 · 폴더 만들기)

채팅에서 `@서버 터미널 열어줘`처럼 말하면, 회사가 지정한 **실제 컴퓨터**에서 그 작업을 실제로 실행합니다. 브라우저는 로컬 파일시스템/터미널에 절대 접근할 수 없으므로, 그 컴퓨터에서 항상 실행 중인 작은 프로그램("에이전트", `bin/remote_agent.dart`)이 대신 실행하고 결과를 돌려줍니다.

컴퓨터는 두 가지 방식으로 지정할 수 있습니다.

- **`@서버`**: 회사 전체에서 쓰는 기본 컴퓨터 한 대 (`--agent-key` 없이 실행한 에이전트가 담당)
- **`@직원이름`**: 그 직원의 자리에 놓인 실제 컴퓨터 — "직원 정보 관리"(화면 우측 상단 배지 🪪 아이콘 — 관리자 화면과는 다른 별도 팝업)에서 그 직원을 **컴퓨터 연결(화이트리스트) 체크박스로 미리 켜둔 경우에만** 동작. 여러 대의 컴퓨터를 직원별로 구분해 명령을 보낼 수 있음 (예: "@도윤 터미널 열어줘"는 도윤의 자리 컴퓨터에서, "@하윤 터미널 열어줘"는 하윤의 자리 컴퓨터에서 실행)

체크박스를 켜지 않은 직원에게는 이 기능이 전혀 적용되지 않습니다 — "터미널"/"폴더" 같은 단어가 든 평범한 업무 요청("@하나 발표자료 폴더에 정리해줘")도 그대로 AI 직원의 LLM 대화로만 처리됩니다.

**보안 설계**: 채팅 메시지가 임의의 셸 명령으로 그대로 실행되지 않습니다 — 에이전트가 수행할 수 있는 작업은 미리 정해진 화이트리스트(`open_terminal`, `create_folder`, `open_terminal_claude`) 뿐이고, 그 외의 말은 "지원하지 않는 명령"으로 거절됩니다. `open_terminal_claude`도 채팅 문장을 그대로 실행하는 게 아니라 정확히 `claude` CLI 하나만 실행하도록 고정돼 있습니다 — 채팅에서 임의의 프로그램/명령을 지정할 수 있는 경로는 없습니다. 또한 컴퓨터 연결은 직원 단위로 명시적으로 켜야만(옵트인) 적용됩니다.

## 동작 방식

1. `@서버 터미널 열어줘` 또는(컴퓨터 연결된 직원에게) `@도윤 터미널 열어줘`처럼 채팅을 보내면, 클라이언트가 문장을 화이트리스트 명령으로 해석(`OfficeGame._parseRemoteCommand`)하고 `remote_commands` 테이블에 `pending` 상태로 한 행을 추가 — `machine_key` 컬럼에 `@서버`면 null, 직원이면 그 직원의 `workstationId`(예: `"desk-1"`)가 들어감
2. 그 컴퓨터에서 실행 중인 `bin/remote_agent.dart`가 (몇 초 간격으로) 자기 담당의 `pending` 행만 확인해 실제로 실행하고, 결과와 함께 `done`/`failed`로 상태를 갱신 — "자기 담당"은 실행 시 준 `--agent-key`와 `machine_key`가 일치하는 행(`--agent-key` 없이 실행했다면 `machine_key`가 null인 행)
3. 클라이언트는 그 행이 갱신되는 것을 Supabase Realtime(Postgres Changes)으로 구독하고 있다가, 완료되면 "서버"(또는 그 직원)가 보낸 채팅 답장처럼 결과를 보여줌(귓속말 · AI 탭, AI 직원 답장과 같은 자리)
4. 에이전트는 회사의 **서비스 롤 키**(비밀 키, 브라우저에는 절대 노출 안 됨)로 동작하므로 RLS를 우회해 상태를 갱신할 수 있음 — 반대로 일반 구성원 계정은 명령을 등록/조회만 할 수 있고 직접 상태를 바꿀 수 없음

## 필요한 설정 — DB 테이블

Supabase SQL Editor에서 아래를 실행해주세요 (몇 번을 다시 실행해도 안전합니다).

```sql
create table if not exists remote_commands (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  requested_by uuid not null references auth.users(id),
  requested_by_name text not null,
  command_type text not null check (command_type in ('open_terminal', 'create_folder', 'open_terminal_claude')),
  params jsonb not null default '{}'::jsonb,
  status text not null default 'pending' check (status in ('pending', 'done', 'failed')),
  result text,
  -- null = the default agent (started without --agent-key). Non-null = a
  -- specific AiEmployee.workstationId (e.g. "desk-1") — an @employee
  -- command only ever sets this when that employee is computerLinked (an
  -- opt-in per-employee whitelist set in the roster editor), so an
  -- ordinary AI employee's normal conversation is never redirected here.
  machine_key text,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

alter table remote_commands add column if not exists machine_key text;

-- 이미 테이블이 있던 경우(위 create table은 no-op) 체크 제약을 다시 만들어
-- open_terminal_claude까지 허용하도록 넓힘.
alter table remote_commands drop constraint if exists remote_commands_command_type_check;
alter table remote_commands add constraint remote_commands_command_type_check
  check (command_type in ('open_terminal', 'create_folder', 'open_terminal_claude'));

alter table remote_commands enable row level security;

drop policy if exists "members_insert_remote_commands" on remote_commands;
drop policy if exists "members_select_remote_commands" on remote_commands;

-- 회사 구성원 누구나(대표/인사관리자/일반 직원) 명령을 등록/조회할 수 있음 —
-- 실제로 무엇을 실행할지는 command_type 화이트리스트가 제한하므로, 등록
-- 자체는 채팅을 보낼 수 있는 사람이면 누구나 가능해도 안전함.
create policy "members_insert_remote_commands" on remote_commands
  for insert with check (
    requested_by = auth.uid()
    and exists (
      select 1 from company_members m
      where m.company_id = remote_commands.company_id and m.user_id = auth.uid()
    )
  );
create policy "members_select_remote_commands" on remote_commands
  for select using (
    exists (
      select 1 from company_members m
      where m.company_id = remote_commands.company_id and m.user_id = auth.uid()
    )
  );

-- UPDATE/DELETE 정책은 의도적으로 없음 — 일반 구성원 계정은 상태를 직접
-- 바꿀 수 없고, 오직 에이전트가 쓰는 서비스 롤 키(RLS를 우회함)만 갱신 가능.

-- Realtime: 클라이언트가 이 테이블의 UPDATE(에이전트가 완료 처리하는 순간)를
-- Postgres Changes로 구독하므로, 이 테이블을 Realtime 발행 목록에 추가해야
-- 함 — 안 하면 에이전트가 실제로는 정상 처리해도(DB에는 done으로 남음) 채팅
-- 화면은 그 사실을 못 받아 타임아웃 메시지만 보임.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'remote_commands'
  ) then
    alter publication supabase_realtime add table remote_commands;
  end if;
end $$;

-- 직원별로 실제 컴퓨터 연결 여부를 저장("직원 정보 관리"(화면 우측 상단 배지 🪪 아이콘 — 관리자 화면과는 다른 별도 팝업)에서
-- 체크박스로 켬/끔) — 기존 employees 테이블 RLS(대표/인사관리자만 수정
-- 가능)를 그대로 씀, 새 정책 불필요.
alter table employees add column if not exists computer_linked boolean not null default false;

notify pgrst, 'reload schema';
```

## 에이전트 실행 — `bin/remote_agent.dart`

순수 `dart:io`만 사용하는 독립 실행 스크립트로, Flutter/외부 패키지가 전혀 필요 없습니다(`pubspec.yaml`에 의존성을 추가하지 않았습니다 — Dart SDK만 설치돼 있으면 바로 실행됩니다). 회사의 그 공용 컴퓨터에서, 아래처럼 **상시 실행**해두면 됩니다.

```bash
# 기본 컴퓨터(@서버) 담당 — --agent-key 없이 실행
dart run bin/remote_agent.dart --company-id <회사 ID> --service-key <서비스 롤 키>

# 특정 직원(예: 도윤)의 컴퓨터 담당 — 그 직원의 workstationId를 --agent-key로
dart run bin/remote_agent.dart --company-id <회사 ID> --service-key <서비스 롤 키> --agent-key project-desk-1
```

- `<회사 ID>`: 그 컴퓨터가 속한 회사의 `companies.id` (Supabase 테이블 편집기에서 확인)
- `<서비스 롤 키>`: Supabase 대시보드 → Project Settings → API Keys의 **service_role**(비밀) 키 — 이 키는 RLS를 완전히 우회하므로 **그 컴퓨터 밖으로 절대 유출되면 안 됩니다** (`.env` 파일이나 환경 변수로 관리하고 커밋하지 마세요). 브라우저/클라이언트 코드에는 이 키가 전혀 들어가지 않습니다.
- `--agent-key`(선택): 특정 직원의 컴퓨터를 담당하게 할 때만 지정 — 그 직원의 `workstationId`("직원 정보 관리"(화면 우측 상단 배지 🪪 아이콘 — 관리자 화면과는 다른 별도 팝업)에서 직원 이름 위에 작게 표시됨, 예: `desk-1`, `project-desk-1`)를 그대로 넣으면 됨. 생략하면 `@서버` 명령만 처리하는 기본 컴퓨터가 됨. 컴퓨터 한 대 = 에이전트 프로세스 한 개(한 `--agent-key`)
- 환경 변수로도 전달 가능: `SUPABASE_SERVICE_ROLE_KEY`, `AI_OFFICE_COMPANY_ID`, `AI_OFFICE_AGENT_KEY`, `SUPABASE_URL`(기본값은 이 프로젝트의 URL)
- 5초 간격으로 자기 담당의 `pending` 명령을 폴링(Realtime WebSocket 없이 단순 HTTPS 요청만 사용 — 패키지 의존성을 늘리지 않기 위한 선택으로, 이 용도엔 몇 초 지연이 문제되지 않음)
- Windows에서 `open_terminal`은 새 `cmd` 창을 엶(`start cmd`), `open_terminal_claude`는 그 창에서 곧바로 `claude` CLI를 실행(`cmd /k claude` — 창이 닫히지 않고 CLI가 계속 떠 있음), `create_folder`는 그 컴퓨터의 바탕화면(`%USERPROFILE%\Desktop`) 아래에 폴더를 만듦 — 이름에 경로 구분자(`/`, `\`)나 `..`가 섞여 있으면 상위 폴더 탈출 방지를 위해 거절
- 콘솔에 처리 로그를 출력 — 터미널을 닫으면 그 컴퓨터를 담당하던 에이전트도 멈추므로(작업 스케줄러/서비스 등록으로 상시 실행하는 것은 이번 범위 밖), 꺼지면 그 컴퓨터로 가는 명령은 "응답하지 않습니다" 타임아웃 메시지로 안내됨(다른 컴퓨터의 에이전트는 영향 없음)

## 직원을 컴퓨터와 연결하기

1. 화면 우측 상단 배지(🪪) 아이콘 → "직원 정보 관리"(관리자 화면과는 다른 별도 팝업, 대표·인사관리자에게만 보임)에서 연결하려는 직원을 찾아 **"실제 컴퓨터와 연결(원격 명령)"** 체크박스를 켬 — 그 직원의 자리 이름(`workstationId`)이 바로 밑에 안내됨
2. 그 자리에 있는 실제 컴퓨터에서 `--agent-key <그 workstationId>`로 에이전트를 실행
3. 이제 `@그 직원 이름 터미널 열어줘`가 그 컴퓨터에서 실행됨 — 체크박스를 끄면 그 직원은 다시 순수 LLM 대화 상대로 돌아감(원격 명령 문구가 들어가도 무시하고 평소처럼 대답)

## 채팅 명령 예시

- `@서버 터미널 열어줘` → 기본 컴퓨터에 새 터미널 창을 엶
- `@서버 보고서 폴더 만들어줘` → 기본 컴퓨터 바탕화면에 "보고서" 폴더 생성
- `@서버 바탕화면에 기획안 폴더 만들어줘` → 위와 동일(부가 표현은 무시하고 이름만 추출)
- `@도윤 터미널 열어줘` → 도윤이 컴퓨터 연결되어 있다면, 도윤 자리 컴퓨터에 터미널을 엶
- `@하윤 터미널 열어서 claude 실행해줘` / `@하윤 클로드 터미널 열어줘` → "터미널"과 함께 "claude"(영문, 대소문자 무관) 또는 "클로드"가 들어가면 터미널을 열면서 그 안에서 곧바로 `claude` CLI까지 실행 — claude 언급이 없으면 그냥 빈 터미널만 열림
- 위 형태에 해당하지 않는 말(연결 안 된 직원에게 보낸 말 포함)은 "지원하지 않는 명령이에요" 안내만 나가거나(`@서버`), 평소처럼 AI 직원의 대답으로 처리됨(연결 안 된 직원)

## 이연된 범위

- 화이트리스트 확장(파일 목록 보기, 파일 삭제, 스크립트 실행 등)은 이번 범위 아님 — `RemoteCommandType`(`lib/data/remote_command.dart`)에 새 항목을 추가하고 에이전트에 대응 로직을 넣는 식으로 이후 확장 가능한 구조로만 만들어둠
- 에이전트를 OS 부팅 시 자동 시작/재시작되는 서비스로 등록하는 것은 이번 범위 아님 — 지금은 사람이 직접 터미널에서 실행해두는 것을 가정
- 자연어 인식은 단순 키워드 매칭 수준(`OfficeGame._parseRemoteCommand`)이라, 문장이 조금만 달라도 인식하지 못할 수 있음 — 위 "채팅 명령 예시"의 표현을 그대로 쓰는 것을 권장
