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

-- 서버기계(게임 속 잠금장치, 아래 "서버 잠금" 참고) — 비밀번호는
-- company_integrations(기존 Slack 웹훅과 같은 테이블)에 저장하되, 일반
-- 구성원은 물론 대표조차 이 컬럼을 직접 SELECT로 읽을 수 없게 막아서
-- (write-only) 클라이언트가 실수로든 의도적으로든 값을 그대로 노출할 길이
-- 없게 함 — 확인/설정은 아래 두 함수(RPC)를 통해서만.
alter table company_integrations add column if not exists server_password text;
revoke select (server_password) on company_integrations from authenticated, anon;

-- 비밀번호를 직접 노출하지 않고 "설정돼 있는지"만 알려줌 — 회사 구성원
-- 누구나 호출 가능(OfficeGame이 로그인 시 잠금 여부를 초기화하는 데 씀).
create or replace function public.has_server_password(target_company_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from company_integrations ci
    join company_members m on m.company_id = ci.company_id
    where ci.company_id = target_company_id
      and m.user_id = auth.uid()
      and ci.server_password is not null
      and ci.server_password <> ''
  );
$$;

-- attempt가 맞는지만 boolean으로 답함 — 실제 값은 절대 돌려주지 않음.
create or replace function public.verify_server_password(target_company_id uuid, attempt text)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from company_integrations ci
    join company_members m on m.company_id = ci.company_id
    where ci.company_id = target_company_id
      and m.user_id = auth.uid()
      and ci.server_password is not null
      and ci.server_password = attempt
  );
$$;

-- 서버기계의 "실행/종료" 전원 스위치 — 비밀번호와 달리 보안 경계가 아니라
-- 게임 속 연출이라, 회사 구성원 누구나 읽고 바꿀 수 있음(대표 전용 아님).
-- 에이전트 프로세스 자체는(예: 아래 "자동 시작"으로) 항상 실행 중일 수
-- 있지만, 이 값이 true일 때만 실제로 명령을 처리함.
create table if not exists server_control (
  company_id uuid primary key references companies(id) on delete cascade,
  running boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table server_control enable row level security;

drop policy if exists "members_read_server_control" on server_control;
drop policy if exists "members_write_server_control" on server_control;

create policy "members_read_server_control" on server_control
  for select using (
    exists (
      select 1 from company_members m
      where m.company_id = server_control.company_id and m.user_id = auth.uid()
    )
  );
create policy "members_write_server_control" on server_control
  for all using (
    exists (
      select 1 from company_members m
      where m.company_id = server_control.company_id and m.user_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from company_members m
      where m.company_id = server_control.company_id and m.user_id = auth.uid()
    )
  );

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
- 콘솔에 처리 로그를 출력 — 터미널을 닫으면 그 컴퓨터를 담당하던 에이전트도 멈추므로, 꺼지면 그 컴퓨터로 가는 명령은 "응답하지 않습니다" 타임아웃 메시지로 안내됨(다른 컴퓨터의 에이전트는 영향 없음). 아래 "자동 시작"으로 등록해두면 이 문제를 크게 줄일 수 있음

## 자동 시작 (Windows, 로그인 시 자동 실행 + 재시작)

매번 손으로 명령을 입력하지 않아도 되도록, 그 컴퓨터에 로그인할 때 에이전트가 자동으로 뜨고 죽으면 자동 재시작되게 등록할 수 있습니다. 관리자 권한이 필요 없는(로그온 시 실행하는) Windows 예약 작업으로 등록합니다.

1. `bin/remote_agent.config.example.json`을 복사해 같은 폴더에 `bin/remote_agent.config.json`으로 저장하고, 실제 값을 채워넣습니다:
   ```json
   {
     "companyId": "회사 ID",
     "serviceKey": "서비스 롤 키",
     "agentKey": "이 컴퓨터가 담당할 workstationId (기본 컴퓨터라면 이 줄은 삭제)"
   }
   ```
   이 파일은 `.gitignore`에 이미 등록돼 있어 커밋되지 않습니다 — 비밀 키가 그대로 들어있으니 그 컴퓨터 밖으로 옮기거나 공유하지 마세요.
2. PowerShell에서 프로젝트 루트로 이동해 설치 스크립트를 실행합니다:
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\install_remote_agent_task.ps1
   ```
   "AI Office Remote Agent"라는 이름의 예약 작업이 등록되고, 이제부터 로그인할 때마다 자동으로 `dart run bin\remote_agent.dart`가 (config 파일 값으로, CLI 인자 없이) 실행됩니다. 죽으면 1분 간격으로 최대 999번까지 자동 재시작됩니다.
3. 지금 바로 시작해보려면: `Start-ScheduledTask -TaskName "AI Office Remote Agent"`
4. 제거하려면: `powershell -ExecutionPolicy Bypass -File scripts\uninstall_remote_agent_task.ps1`

`Register-ScheduledTask`가 "액세스가 거부되었습니다"로 실패하면, PowerShell을 **관리자 권한으로 실행**해서 다시 시도해주세요(일부 Windows 환경에서는 로그온 트리거 작업 등록에도 관리자 권한이 필요합니다).

### 한 컴퓨터에서 여러 에이전트 실행하기

컴퓨터 한 대에 사람이 앉아 있지 않거나, 기본 컴퓨터(`@서버`)와 특정 직원의 컴퓨터를 **같은 컴퓨터**에서 같이 돌리고 싶다면, config 파일과 예약 작업 이름을 다르게 줘서 여러 개 등록할 수 있습니다:

```powershell
# 두 번째 config 파일 (예: 기본 컴퓨터용 — agentKey 줄 없이)
@'
{
  "companyId": "회사 ID",
  "serviceKey": "서비스 롤 키"
}
'@ | Out-File -FilePath bin\remote_agent.default.config.json -Encoding utf8

# -TaskName과 -ConfigFile을 다르게 줘서 두 번째 예약 작업 등록
powershell -ExecutionPolicy Bypass -File scripts\install_remote_agent_task.ps1 `
  -TaskName "AI Office Remote Agent (기본 컴퓨터)" `
  -ConfigFile "remote_agent.default.config.json"
```

`bin/remote_agent.dart`는 `--config <파일명>`을 받아 그 파일을 읽습니다(생략하면 기본값 `remote_agent.config.json`) — 설치 스크립트가 이걸 자동으로 넘겨줍니다. config 파일 이름은 `bin/remote_agent.*.config.json` 패턴이면 `.gitignore`에 이미 걸려 커밋되지 않습니다.

macOS/Linux는 이번 범위 밖입니다 — `cron`의 `@reboot`이나 `launchd`/`systemd` 서비스로 비슷하게 만들 수 있지만, 스크립트로 제공하지는 않습니다.

## 직원을 컴퓨터와 연결하기

1. 화면 우측 상단 배지(🪪) 아이콘 → "직원 정보 관리"(관리자 화면과는 다른 별도 팝업, 대표·인사관리자에게만 보임)에서 연결하려는 직원을 찾아 **"실제 컴퓨터와 연결(원격 명령)"** 체크박스를 켬 — 그 직원의 자리 이름(`workstationId`)이 바로 밑에 안내됨
2. 그 자리에 있는 실제 컴퓨터에서 `--agent-key <그 workstationId>`로 에이전트를 실행
3. 이제 `@그 직원 이름 터미널 열어줘`가 그 컴퓨터에서 실행됨 — 체크박스를 끄면 그 직원은 다시 순수 LLM 대화 상대로 돌아감(원격 명령 문구가 들어가도 무시하고 평소처럼 대답)

## 서버 잠금 (게임 속 서버기계)

2층에 클릭 가능한 "서버기계" 오브젝트가 있습니다. **`@서버`(기본 컴퓨터) 원격 명령만** 이 잠금의 영향을 받습니다 — 컴퓨터 연결된 특정 직원(`@도윤`, `@하윤` 등)은 그 직원 자체의 옵트인 체크박스로만 제어되고, 이 비밀번호와는 무관합니다.

- 대표가 관리자 화면에서 **서버 잠금 비밀번호**를 설정하면(비워두면 잠금 자체가 꺼짐 — 기본값), 그때부터 아무도 `@서버` 명령을 바로 쓸 수 없고, 2층 서버기계를 클릭해 그 비밀번호를 맞혀야 그 로그인 세션 동안 풀립니다(새로고침/재로그인하면 다시 잠김)
- 보안 참고: 이건 **게임 속 재미 요소**입니다 — 실제 보안 경계는 여전히 명령 화이트리스트와 직원별 옵트인이고, 이 비밀번호는 그 위에 얹은 부가 절차일 뿐입니다. 관리자 화면과 확인 절차는 값을 다시 보여주지 않도록(write-only UI, `verify_server_password` RPC로 boolean만 확인) 만들었지만, **알려진 한계**: `revoke select (server_password) ...`로 클라이언트의 직접 조회 자체를 막으려 했는데 라이브 테스트에서 실제로는 막히지 않는 것을 확인했습니다(`company_integrations.select('server_password')`로 여전히 평문 조회 가능) — 원인 미파악, 후속 조치 필요(`docs/STATUS.md` 참고). 그래도 게임 속 재미 요소일 뿐이라는 점은 변함없습니다
- 관리자 화면의 비밀번호 입력창은 항상 비어 있는 채로 시작합니다 — 바꾸고 싶을 때만 새 값을 입력하세요(빈 채로 저장하면 잠금이 꺼짐)

### 서버 실행 / 종료 (전원 스위치)

잠금을 해제하면 서버기계 팝업에 **"서버 실행"/"서버 종료"** 버튼이 나타납니다.

- 에이전트 프로세스 자체는 (예: 위 "자동 시작"으로) 그 컴퓨터에서 항상 실행 중일 수 있지만, 실제로 `pending` 명령을 처리하는 건 이 스위치가 **"실행"** 상태일 때뿐입니다 — 꺼져 있으면 에이전트가 명령을 곧바로 `failed`로 표시하고 "서버가 꺼져 있습니다" 안내만 돌려줍니다(터미널을 열거나 폴더를 만드는 등 실제 동작은 전혀 하지 않음)
- **`server_control`은 컴퓨터별이 아니라 회사 하나당 값 하나**입니다 — `@서버`(기본 컴퓨터)만이 아니라, 직원별로 연결된 모든 컴퓨터의 에이전트가 전부 이 같은 스위치를 확인합니다. 즉 서버기계에서 한 번 끄면 하윤·도윤 등 컴퓨터 연결된 모든 직원의 명령도 같이 멈추고, 켜면 전부 다시 처리됩니다 — 컴퓨터별 개별 스위치가 아니라 **회사 전체 공용 스위치 하나**입니다
- 비밀번호와 달리 이건 **보안 경계가 아니라 전원 버튼**이라, 잠금을 해제한 회사 구성원 누구나 켜고 끌 수 있고, 회사 전체가 공유하는 상태입니다(한 사람이 켜면 다른 사람도 바로 그 상태로 씀) — 다만 이 클라이언트는 그 상태를 실시간으로 동기화하지 않으므로, 다른 사람이 방금 바꾼 상태는 서버기계 팝업을 다시 열어야 반영됩니다
- 브라우저는 실제 컴퓨터의 프로세스를 켜거나 끌 수 없으므로(그래서 애초에 별도 에이전트가 필요했던 것과 같은 이유), 이 버튼이 하는 일은 "에이전트를 실행시키는 것"이 아니라 "이미 실행 중인 에이전트에게 처리를 허락/보류시키는 것"입니다 — 에이전트 프로세스 자체가 꺼져 있다면(예: 컴퓨터가 꺼져 있거나 예약 작업이 등록 안 된 경우) 이 스위치를 켜도 아무 일도 일어나지 않고, 45초 뒤 평소처럼 "응답하지 않습니다" 타임아웃 안내가 나갑니다

## 채팅 명령 예시

- `@서버 터미널 열어줘` → 기본 컴퓨터에 새 터미널 창을 엶
- `@서버 보고서 폴더 만들어줘` → 기본 컴퓨터 바탕화면에 "보고서" 폴더 생성
- `@서버 바탕화면에 기획안 폴더 만들어줘` → 위와 동일(부가 표현은 무시하고 이름만 추출)
- `@도윤 터미널 열어줘` → 도윤이 컴퓨터 연결되어 있다면, 도윤 자리 컴퓨터에 터미널을 엶
- `@하윤 터미널 열어서 claude 실행해줘` / `@하윤 클로드 터미널 열어줘` → "터미널"과 함께 "claude"(영문, 대소문자 무관) 또는 "클로드"가 들어가면 터미널을 열면서 그 안에서 곧바로 `claude` CLI까지 실행 — claude 언급이 없으면 그냥 빈 터미널만 열림
- 위 형태에 해당하지 않는 말(연결 안 된 직원에게 보낸 말 포함)은 "지원하지 않는 명령이에요" 안내만 나가거나(`@서버`), 평소처럼 AI 직원의 대답으로 처리됨(연결 안 된 직원)

## 이연된 범위

- 화이트리스트 확장(파일 목록 보기, 파일 삭제, 스크립트 실행 등)은 이번 범위 아님 — `RemoteCommandType`(`lib/data/remote_command.dart`)에 새 항목을 추가하고 에이전트에 대응 로직을 넣는 식으로 이후 확장 가능한 구조로만 만들어둠
- ~~에이전트를 OS 부팅 시 자동 시작/재시작되는 서비스로 등록하는 것은 이번 범위 아님~~ — 후속 반영에서 완료(위 "자동 시작" 참고): Windows 로그온 시 예약 작업으로 자동 실행 + 크래시 시 자동 재시작(`scripts/install_remote_agent_task.ps1`). macOS/Linux는 여전히 범위 밖
- 자연어 인식은 단순 키워드 매칭 수준(`OfficeGame._parseRemoteCommand`)이라, 문장이 조금만 달라도 인식하지 못할 수 있음 — 위 "채팅 명령 예시"의 표현을 그대로 쓰는 것을 권장
