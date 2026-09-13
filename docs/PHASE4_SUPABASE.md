# Phase 4 — Supabase 연동

## 프로젝트

- Project URL: `https://sybdrgllifzrbwqgkkff.supabase.co`
- Publishable (anon) key: `lib/supabase_config.dart`에 저장됨. 브라우저에 노출돼도 안전하지만, 아래 RLS 정책이 반드시 적용되어 있어야 합니다.

## DB 스키마 (Supabase 대시보드 → SQL Editor에서 실행)

한 사용자당 회사 하나(MVP), 회사에 AI 직원 로스터가 딸려 있는 구조입니다.

```sql
create table if not exists companies (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null default '내 회사',
  created_at timestamptz not null default now()
);

create unique index if not exists companies_owner_id_key on companies(owner_id);

-- Per-user role within a company. The creator is inserted as 'owner' when
-- the company is created; 'hr_manager' rows are for future invited admins.
create table if not exists company_members (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'hr_manager', 'member')),
  created_at timestamptz not null default now(),
  unique (company_id, user_id)
);

create table if not exists employees (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  workstation_id text not null,
  name text not null,
  role text not null,
  provider text not null,
  status text not null default 'idle',
  updated_at timestamptz not null default now(),
  unique (company_id, workstation_id)
);

alter table companies enable row level security;
alter table company_members enable row level security;
alter table employees enable row level security;

-- Policies are dropped first so this whole script is safe to run again
-- (e.g. after adding company_members, or just to double-check state) —
-- CREATE POLICY has no IF NOT EXISTS, so re-running it as-is would error
-- with "policy already exists" instead of updating it.
drop policy if exists "owner_select_company" on companies;
drop policy if exists "owner_insert_company" on companies;
drop policy if exists "owner_update_company" on companies;
drop policy if exists "owner_delete_company" on companies;
drop policy if exists "self_select_membership" on company_members;
drop policy if exists "owner_manage_members" on company_members;
drop policy if exists "owner_select_employees" on employees;
drop policy if exists "owner_insert_employees" on employees;
drop policy if exists "owner_update_employees" on employees;
drop policy if exists "owner_delete_employees" on employees;
drop policy if exists "managers_select_employees" on employees;
drop policy if exists "managers_insert_employees" on employees;
drop policy if exists "managers_update_employees" on employees;
drop policy if exists "managers_delete_employees" on employees;

create policy "owner_select_company" on companies
  for select using (auth.uid() = owner_id);
create policy "owner_insert_company" on companies
  for insert with check (auth.uid() = owner_id);
create policy "owner_update_company" on companies
  for update using (auth.uid() = owner_id);
create policy "owner_delete_company" on companies
  for delete using (auth.uid() = owner_id);

-- Members can see their own membership row; only the company owner can
-- add/change/remove members (i.e. invite an HR manager later).
create policy "self_select_membership" on company_members
  for select using (auth.uid() = user_id);
create policy "owner_manage_members" on company_members
  for all using (
    exists (select 1 from companies c where c.id = company_members.company_id and c.owner_id = auth.uid())
  ) with check (
    exists (select 1 from companies c where c.id = company_members.company_id and c.owner_id = auth.uid())
  );

-- Only owner/hr_manager members can read or edit the employee roster.
create policy "managers_select_employees" on employees
  for select using (
    exists (
      select 1 from company_members m
      where m.company_id = employees.company_id
        and m.user_id = auth.uid()
        and m.role in ('owner', 'hr_manager')
    )
  );
create policy "managers_insert_employees" on employees
  for insert with check (
    exists (
      select 1 from company_members m
      where m.company_id = employees.company_id
        and m.user_id = auth.uid()
        and m.role in ('owner', 'hr_manager')
    )
  );
create policy "managers_update_employees" on employees
  for update using (
    exists (
      select 1 from company_members m
      where m.company_id = employees.company_id
        and m.user_id = auth.uid()
        and m.role in ('owner', 'hr_manager')
    )
  );
create policy "managers_delete_employees" on employees
  for delete using (
    exists (
      select 1 from company_members m
      where m.company_id = employees.company_id
        and m.user_id = auth.uid()
        and m.role in ('owner', 'hr_manager')
    )
  );

-- Tell PostgREST to reload its schema cache immediately, instead of
-- waiting for its normal refresh interval. Run this after any schema
-- change if the app immediately reports "table ... not found".
notify pgrst, 'reload schema';
```

이 SQL 전체는 몇 번을 다시 실행해도 안전합니다(정책을 먼저 지우고 다시 만듭니다). "policy already exists" 같은 에러가 나면 옛날 버전의 스크립트를 실행하신 것이니, 위 최신 SQL 전체를 그대로 다시 실행하시면 됩니다.

## 인사관리자 초대 (추가 SQL)

"직원 정보 관리" 패널에서 대표/인사관리자가 아이디로 다른 사람을 초대할 수 있습니다. 아래 SQL을 위 스키마에 이어서 실행해주세요 (역시 몇 번을 다시 실행해도 안전합니다).

```sql
create table if not exists invites (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  email text not null,
  role text not null default 'member' check (role in ('hr_manager', 'member')),
  invited_by uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now()
);

alter table invites enable row level security;

drop policy if exists "managers_select_invites" on invites;
drop policy if exists "managers_insert_invites" on invites;
drop policy if exists "managers_delete_invites" on invites;
drop policy if exists "invitee_select_own_invites" on invites;
drop policy if exists "invitee_update_own_invites" on invites;
drop policy if exists "invitee_join_via_invite" on company_members;

-- A policy on `invites` that queries `company_members`, combined with a
-- policy on `company_members` that queries `invites` (see
-- "invitee_join_via_invite" below), makes Postgres reject the query with
-- "infinite recursion detected in policy for relation company_members" —
-- it can't tell the two tables' policies won't loop forever. A
-- SECURITY DEFINER function breaks the cycle: it runs with the row
-- security of its owner (bypassing RLS internally), so referencing it
-- from a policy doesn't count as the policy itself querying the table.
create or replace function public.is_company_manager(target_company_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from company_members m
    where m.company_id = target_company_id
      and m.user_id = auth.uid()
      and m.role in ('owner', 'hr_manager')
  );
$$;

-- Only the inviting company's owner/hr_manager can see, create, or
-- withdraw invites for that company.
create policy "managers_select_invites" on invites
  for select using (is_company_manager(invites.company_id));
create policy "managers_insert_invites" on invites
  for insert with check (
    invited_by = auth.uid() and is_company_manager(invites.company_id)
  );
create policy "managers_delete_invites" on invites
  for delete using (is_company_manager(invites.company_id));

-- The invited person (matched by their own login email, before they have
-- any company membership) can see and accept their own pending invite.
create policy "invitee_select_own_invites" on invites
  for select using (
    lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
create policy "invitee_update_own_invites" on invites
  for update using (
    lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  ) with check (
    lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Lets the invited person insert their OWN company_members row once, but
-- only when a matching pending invite exists — this is what turns
-- "accepting an invite" into actually joining the company. Coexists with
-- "owner_manage_members" (Postgres OR's matching policies together).
create policy "invitee_join_via_invite" on company_members
  for insert with check (
    user_id = auth.uid()
    and exists (
      select 1 from invites i
      where i.company_id = company_members.company_id
        and i.status = 'pending'
        and lower(i.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    )
  );

notify pgrst, 'reload schema';
```

### 동작 방식

1. 대표/인사관리자가 패널의 "구성원 초대"에서 아이디 + 역할(인사관리자/일반 직원)을 입력하면 `invites` 테이블에 `pending` 행이 생성됨 (실제 알림/메일은 보내지 않음 — 초대받은 사람에게 아이디/비밀번호를 직접 알려줘야 함)
2. 초대받은 아이디로 회원가입하거나 로그인하면 `CompanyRepository.ensureCompany()`가 (1) 본인 소유 회사 → (2) 이미 속한 회사 → (3) 자신의 이메일로 온 대기 중 초대 순으로 확인, 일치하는 초대가 있으면 그 회사에 지정된 역할로 합류하고 초대를 `accepted`로 표시
3. 일치하는 초대가 없으면 기존과 동일하게 새 회사를 만듦 (1인 1회사 기본 동작 유지)

## 인증

Authentication → Providers → Email이 켜져 있어야 합니다 (기본값).

**로그인은 이메일이 아니라 "아이디"로 표시됩니다.** Supabase Auth는 내부적으로 항상 이메일 기반이라, 앱에서 입력한 아이디를 `아이디@mailinator.com` 형태의 가상 이메일로 변환해서 사용합니다(`lib/data/username_auth.dart`).

- `.local`/`.internal`/`.test` 같은 예약 TLD, 그리고 `ai-office.com`처럼 실제 존재하지 않는 도메인도 전부 시도해봤지만 Supabase가 **도메인의 MX 레코드(실제 존재 여부)까지 검증**해서 거부했습니다. 그래서 실제 존재하고 MX 레코드가 있는 `mailinator.com`(가짜 회원가입용으로 널리 쓰이는 공개 더미 메일함 서비스)을 사용합니다.
- **중요**: `@mailinator.com`으로 온 메일은 **누구나 읽을 수 있는 공개 메일함**입니다. 그래서 **Authentication → Settings → "Confirm email"을 반드시 꺼두세요** — 켜두면 확인 메일이 공개 메일함으로 가서 아무나 계정을 가로챌 수 있습니다. 나중에라도 "비밀번호 재설정(이메일)" 같은 기능을 추가하면 안 됩니다(같은 이유). 로그인 화면의 "비밀번호를 잊으셨나요?" 링크도 이메일 재설정과 연결하지 마세요.
- **"Confirm email"이 켜져 있으면** 회원가입할 때마다 확인 메일을 실제로 보내려 시도하다가 Supabase 무료 티어의 시간당 발송 한도에 금방 걸려 `email rate limit exceeded` 에러가 납니다. 이 에러가 보이면 곧 "Confirm email"이 아직 켜져 있다는 뜻이니 꺼주시고, 한도가 리셋될 때까지(보통 1시간 이내) 기다렸다가 다시 시도하세요.

## 앱 동작

1. `main.dart`에서 `Supabase.initialize`로 클라이언트 초기화
2. `AuthGate`가 로그인 상태를 감시 — 미로그인 시 `LoginScreen`(이메일+비밀번호, 회원가입 겸용), 로그인 시 회사·역할·직원 로스터를 불러온 뒤 `OfficeScreen` 표시
3. 첫 로그인 시 `CompanyRepository.ensureCompany()`가 회사를 자동 생성하고, 그 사용자를 `company_members`에 `owner`(대표) 역할로 등록하고, 샘플 직원 3명으로 시드
4. `owner`/`hr_manager` 역할만 "직원 정보 관리" 패널을 열 수 있음 (`member` 역할은 버튼이 비활성화됨) — `docs`의 RLS 정책이 서버 쪽에서도 동일하게 강제함
5. 패널에서 직원 정보를 수정하면 `CompanyRepository.upsertEmployee()`로 Supabase에 저장
6. 다시 로그인하면 저장된 회사·직원 구성이 그대로 복원됨 (완료 기준 충족)

## 역할(role)

- `owner`(대표): 회사를 만든 사람. 자동 부여.
- `hr_manager`(인사관리자): 대표/인사관리자가 "구성원 초대"로 초대할 수 있는 역할.
- `member`(일반 직원): 로스터 조회/수정 불가, 초대는 가능.

## 이연된 범위

- 오피스 레이아웃(층별 배치) 저장은 이번 범위에 포함하지 않음 — 현재는 고정 레이아웃 그대로 사용
- 플레이어 프로필(이름/직책/상태) 영속화는 이번 범위에 포함하지 않음 — 세션 내에서만 유지
- 초대는 인앱 알림/메일 발송 없이 아이디만 등록함 — 초대받은 사람에게 아이디/비밀번호를 별도로 전달해야 함
