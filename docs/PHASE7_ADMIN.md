# Phase 7 (일부) — 관리자 화면 · 감사 기록 · 권한 강화

## 관리자 화면

화면 우측 상단의 관리자(🛡) 아이콘 — **대표(owner)에게만 보입니다.** "직원 정보 관리"(AI 직원 로스터)와는 별개로, 실제로 로그인하는 사람들(구성원)의 목록과 역할을 봅니다.

- 구성원 목록: 아이디 + 역할. 대표 본인 행은 역할을 바꿀 수 없음(자기 자신을 강등해 잠기는 사고 방지)
- 다른 구성원의 역할을 "일반 직원"/"인사관리자" 사이에서 변경 가능 — 대표 역할 자체를 남에게 넘기는 기능(소유권 이전)은 없음
- "감사 기록 보기" 버튼으로 활동 기록(아래) 패널을 그대로 엶

## 감사 기록

기존 활동 기록(`docs/PHASE7_ACTIVITY.md`)에 **누가** 했는지(`actor_name`)를 추가했습니다. 지금까지는 "무엇을 했는지"만 있었는데, 이제 "OOO · 방금 전"처럼 행위자까지 표시됩니다.

## 권한 강화

- **관리자 화면 자체가 대표 전용**입니다 — 인사관리자는 AI 직원 로스터는 관리할 수 있지만(기존 그대로), 실제 계정 목록을 보거나 역할을 바꿀 수 없습니다.
- **"인사관리자" 초대는 대표만 가능**하도록 좁혔습니다 — 이전에는 인사관리자도 "구성원 초대"에서 다른 사람을 인사관리자로 초대할 수 있었는데(같은 권한의 동료를 스스로 만들 수 있는 권한 상승 구멍), 이제 인사관리자는 "일반 직원"만 초대할 수 있고, 화면에서도 "인사관리자" 선택지가 아예 안 보입니다. **서버(RLS)에서도 같은 규칙을 강제**하므로, 클라이언트를 우회해도 인사관리자 역할의 초대는 대표가 보낸 것만 통과합니다.

## 필요한 설정 — DB 변경

아래 SQL을 Supabase SQL Editor에서 실행해주세요 (몇 번을 다시 실행해도 안전합니다). `docs/PHASE4_SUPABASE.md`(기본 스키마)와 `docs/PHASE7_ACTIVITY.md`(`activity_events` 테이블)를 먼저 실행하셨어야 합니다.

**주의**: `docs/PHASE7_ACTIVITY.md`의 SQL을 `docs/PHASE7_BOARD.md`/`docs/PHASE7_MEETING.md`보다 먼저 실행하셨다면, `activity_events.type`의 체크 제약이 아직 `'board'`/`'meeting'` 값을 허용하지 않아서 업무 보드·회의 관련 활동 기록 저장이 조용히 실패하고 있었을 수 있습니다(채팅 응답 등 나머지 기능엔 영향 없음). 아래 SQL이 그 제약도 함께 넓힙니다.

```sql
-- 1) 감사 기록: 활동 기록에 행위자 이름 추가.
alter table activity_events add column if not exists actor_name text;

-- 1-1) 위 주의사항: type 체크 제약을 board/meeting까지 허용하도록 재생성.
alter table activity_events drop constraint if exists activity_events_type_check;
alter table activity_events add constraint activity_events_type_check
  check (type in ('employee', 'ai_command', 'member', 'board', 'meeting'));

-- 2) 관리자 화면: 대표가 자기 회사 구성원의 아이디(이메일)를 볼 수 있는
--    함수. auth.users는 클라이언트에서 직접 조회할 수 없어서, 이 함수가
--    (호출자가 그 회사의 대표일 때만) 대신 조회해줍니다 — 회사 소유 여부는
--    함수 안에서 직접 확인합니다(SECURITY DEFINER는 RLS를 우회하므로).
create or replace function public.company_members_with_email(target_company_id uuid)
returns table (user_id uuid, email text, role text, created_at timestamptz)
language sql
security definer
set search_path = public
stable
as $$
  select m.user_id, u.email, m.role, m.created_at
  from company_members m
  join auth.users u on u.id = m.user_id
  where m.company_id = target_company_id
    and exists (
      select 1 from companies c
      where c.id = target_company_id and c.owner_id = auth.uid()
    );
$$;

-- 3) 권한 강화: 인사관리자는 "일반 직원"만 초대할 수 있고, "인사관리자"
--    초대는 대표만 보낼 수 있도록 초대 정책을 좁힙니다.
drop policy if exists "managers_insert_invites" on invites;
create policy "managers_insert_invites" on invites
  for insert with check (
    invited_by = auth.uid()
    and (
      (role = 'member' and is_company_manager(invites.company_id))
      or (
        role = 'hr_manager'
        and exists (
          select 1 from companies c
          where c.id = invites.company_id and c.owner_id = auth.uid()
        )
      )
    )
  );

notify pgrst, 'reload schema';
```

구성원 역할 변경(`updateMemberRole`) 자체는 새 정책이 필요 없습니다 — `docs/PHASE4_SUPABASE.md`의 `owner_manage_members` 정책이 이미 대표에게 `company_members`에 대한 전체 권한(조회/추가/수정/삭제)을 주고 있습니다.

## 이연된 범위

- ~~행위자는 표시 이름(`actor_name`)만 기록~~ — `docs/PHASE7_OPS_REVIEW.md`의 후속 반영에서 안정적인 사용자 ID(`actor_user_id`)도 함께 기록하도록 추가됨 (UI에는 아직 노출 안 함)
- 대표 역할 자체의 이전(소유권 양도)은 이번 범위 아님
- 구성원 강퇴(회사에서 제거)는 이번 범위 아님 — 역할 변경만 가능
- 감사 기록의 필터/검색(행위자별, 기간별 등)은 이번 범위 아님 — 최근 50건을 그대로 봄
