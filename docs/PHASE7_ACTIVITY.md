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

notify pgrst, 'reload schema';
```

## 앱 동작

1. `OfficeGame._logActivity()`가 이벤트를 세션 메모리 목록(최근 50건)에 추가하고 안 읽은 개수를 늘린 뒤, `onActivityLogged` 콜백으로 알림
2. `AuthGate`가 그 콜백을 `ActivityRepository.logEvent()`에 연결해 Supabase에 저장(best-effort — 실패해도 활동 기록 화면에는 이미 반영됨)
3. 로그인 시 `ActivityRepository.fetchRecentActivity()`가 최근 50건을 불러와 `OfficeGame(initialActivity: ...)`로 복원
4. 안 읽은 개수(`unreadActivityCount`)는 세션 메모리에만 있는 로컬 상태입니다 — 재로그인하면 새로 불러온 활동 기록에 대해 다시 "안 읽음"으로 시작합니다(즉, "마지막으로 읽은 지점" 자체는 서버에 저장하지 않음)

## 이연된 범위

- 구성원 초대/합류(`CompanyRepository.inviteMember`/`ensureCompany`의 초대 수락)는 아직 활동 기록에 남기지 않음 — "직원 정보 관리" 패널의 "구성원 초대" 목록에서 별도로 확인 가능
- 안 읽음 상태 자체의 서버 영속화(마지막으로 읽은 시각 등)는 이번 범위 아님
- 활동 기록 자체를 실시간(다른 로그인 세션에도 즉시)으로 반영하는 건 이번 범위 아님 — 로그인 시점에 한 번 불러올 뿐, Realtime 구독은 하지 않음
