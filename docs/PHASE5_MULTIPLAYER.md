# Phase 5 — 멀티플레이와 채팅

## 실시간 위치 공유

`docs/PHASE4_SUPABASE.md`의 스키마(회사·직원·역할)에 추가로, DB 테이블은 필요 없습니다 — 위치 공유는 Supabase **Realtime Presence**만 사용합니다 (`office:company:<companyId>` 채널). 별도 SQL 실행이 필요 없습니다.

- `MultiplayerChannel`이 회사별 채널에 접속해 이름·직책·상태·층·좌표를 공유
- 같은 층에 있는 사용자만 화면에 렌더링됨
- 이동은 150ms 간격으로 전송(스로틀), 층 이동/프로필 변경은 즉시 전송

## 공간 채팅

채팅은 **Realtime Broadcast**(실시간 전달) + **DB 저장**(기록 보관) 두 가지를 함께 씁니다. 아래 SQL을 Supabase SQL Editor에서 실행해주세요.

```sql
create table if not exists messages (
  -- Text, not uuid: the client generates this id as
  -- "<epoch-micros>-<userId>" rather than a real UUID.
  id text primary key,
  company_id uuid not null references companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  sender_name text not null,
  body text not null,
  created_at timestamptz not null default now()
);

alter table messages enable row level security;

drop policy if exists "members_select_messages" on messages;
drop policy if exists "members_insert_messages" on messages;

-- Any company member (owner/hr_manager/member) can read and post to the
-- company's space chat — this isn't gated by role like the roster panel.
create policy "members_select_messages" on messages
  for select using (
    exists (
      select 1 from company_members m
      where m.company_id = messages.company_id and m.user_id = auth.uid()
    )
  );
create policy "members_insert_messages" on messages
  for insert with check (
    user_id = auth.uid()
    and exists (
      select 1 from company_members m
      where m.company_id = messages.company_id and m.user_id = auth.uid()
    )
  );

notify pgrst, 'reload schema';
```

이 SQL도 몇 번을 다시 실행해도 안전합니다.

## 앱 동작

1. 로그인 시 최근 메시지 50개를 불러와 채팅 패널에 표시 (`ChatRepository.fetchRecentMessages`)
2. 화면 우측 상단 채팅 아이콘으로 패널 열기/닫기 (열려 있는 동안 이동 비활성화)
3. 메시지 전송 시: 로컬에 즉시 표시 → 같은 회사 채널로 실시간 브로드캐스트 → DB에 저장
4. `messages` 테이블이 아직 없어도(SQL 미실행) 앱 전체가 깨지지 않고 채팅 기록만 비어 있는 상태로 시작함 (`catchError`로 방어)

## 이연된 범위

- 직원별(=AI 직원과의) 대화 기록은 이번 범위 아님 — 컴퓨터 팝업의 "대화하기" 버튼은 여전히 placeholder
- 인사관리자 초대 UI는 이연 (Phase 4/5 공통 이슈, `docs/PHASE4_SUPABASE.md` 참고)
