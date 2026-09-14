# Phase 7 (일부) — 알림과 활동 기록

회사 안에서 일어난 일을 한곳에서 볼 수 있는 활동 피드입니다. 지금은 두 가지를 기록합니다.

- **직원 정보 수정** — "직원 정보 관리" 패널에서 이름/역할/상태를 바꿀 때 (`OfficeGame.updateEmployee`)
- **AI 직원 명령 결과** — `@직원이름 명령`이 성공하거나(재시도 포함 최종) 실패했을 때

화면 우측 상단의 알림(🔔) 아이콘에 안 읽은 개수 배지가 뜨고, 누르면 "활동 기록" 패널이 열리면서 배지가 초기화됩니다.

## 필요한 설정 — DB 테이블 추가

재로그인 후에도 활동 기록이 남아있으려면 아래 SQL을 Supabase SQL Editor에서 실행해주세요 (몇 번을 다시 실행해도 안전합니다). 실행 전에는 활동 기록이 세션 메모리에만 있다가 새로고침 시 사라지지만, 앱 자체는 정상 동작합니다.

```sql
create table if not exists activity_events (
  -- Text, not uuid: matches OfficeGame's client-generated event ids
  -- ("<epoch-micros>-activity"), same convention as `messages.id`.
  id text primary key,
  company_id uuid not null references companies(id) on delete cascade,
  type text not null check (
    type in ('employee', 'ai_command', 'member', 'board', 'meeting')
  ),
  message text not null,
  -- The signed-in player's display name when this was logged — added in
  -- docs/PHASE7_ADMIN.md's audit-log pass; included here too so a fresh
  -- install gets it from the start. Nullable: older rows won't have it.
  actor_name text,
  -- The signed-in user's stable Supabase auth id when this was logged —
  -- added in docs/PHASE7_OPS_REVIEW.md's follow-up pass, unlike actor_name
  -- this never changes if the account is renamed. Nullable: older rows and
  -- events logged outside a signed-in session (e.g. tests) won't have it.
  actor_user_id uuid,
  created_at timestamptz not null default now()
);

alter table activity_events enable row level security;

drop policy if exists "members_select_activity_events" on activity_events;
drop policy if exists "members_insert_activity_events" on activity_events;

create policy "members_select_activity_events" on activity_events
  for select using (
    exists (
      select 1 from company_members m
      where m.company_id = activity_events.company_id and m.user_id = auth.uid()
    )
  );
create policy "members_insert_activity_events" on activity_events
  for insert with check (
    exists (
      select 1 from company_members m
      where m.company_id = activity_events.company_id and m.user_id = auth.uid()
    )
  );

-- 각 사용자가 이 회사의 활동 기록을 마지막으로 언제 읽었는지 — 안 읽음 배지를
-- 서버에 영속화하기 위한 테이블(companies/company_members는 건드리지 않음).
-- company_members에 컬럼을 추가하는 대신 별도 테이블로 둔 이유: 그 테이블의
-- RLS는 "자기 자신의 행만 UPDATE 가능"을 role/company_id 컬럼까지 포함해
-- 안전하게 표현하기 어려운데(자기 역할을 자기가 바꿔버릴 수 있는 구멍이 될
-- 위험), 이 테이블은 오직 이 용도 하나뿐이라 "user_id = auth.uid()"만으로
-- 전체 컬럼을 안전하게 열어줄 수 있음.
create table if not exists activity_read_marks (
  company_id uuid not null references companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  last_read_at timestamptz not null default now(),
  primary key (company_id, user_id)
);

alter table activity_read_marks enable row level security;

drop policy if exists "self_manage_activity_read_marks" on activity_read_marks;
create policy "self_manage_activity_read_marks" on activity_read_marks
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

notify pgrst, 'reload schema';
```

## 앱 동작

1. `OfficeGame._logActivity()`가 이벤트를 세션 메모리 목록(최근 50건)에 추가하고 안 읽은 개수를 늘린 뒤, `onActivityLogged` 콜백으로 알림
2. `AuthGate`가 그 콜백을 `ActivityRepository.logEvent()`에 연결해 Supabase에 저장(best-effort — 실패해도 활동 기록 화면에는 이미 반영됨)
3. 로그인 시 `ActivityRepository.fetchRecentActivity()`가 최근 50건을 불러와 `OfficeGame(initialActivity: ...)`로 복원
4. 안 읽은 개수(`unreadActivityCount`)는 로그인 시 함께 불러온 `activity_read_marks.last_read_at`(내가 마지막으로 읽은 시각) 기준으로 복원됩니다 — 그 시각 이후에 로그된 이벤트만 "안 읽음"으로 집니다. 이 마크가 아예 없으면(첫 로그인, 또는 아직 SQL 미실행) 전체를 "이미 읽음"으로 간주해 시작합니다(불러온 과거 이력 전체가 갑자기 안 읽음으로 뜨는 것을 방지)
5. "활동 기록" 패널을 열 때마다 `OfficeGame.markActivityRead()`가 현재 시각을 `onActivityRead` 콜백으로 알리고, `AuthGate`가 `ActivityRepository.markRead()`로 Supabase에 저장(best-effort)

## 이연된 범위

- 구성원 초대/합류(`CompanyRepository.inviteMember`/`ensureCompany`의 초대 수락)는 아직 활동 기록에 남기지 않음 — "직원 정보 관리" 패널의 "구성원 초대" 목록에서 별도로 확인 가능
- 활동 기록 자체를 실시간(다른 로그인 세션에도 즉시)으로 반영하는 건 이번 범위 아님 — 로그인 시점에 한 번 불러올 뿐, Realtime 구독은 하지 않음
