# Phase 8 — 외부 서비스 연동 (Slack 웹훅)

활동 기록(직원 정보 수정, AI 직원 명령 성공/실패, 업무 보드, 회의, 감사 기록 등 — `docs/PHASE7_ACTIVITY.md`)에 남는 모든 이벤트를 회사가 지정한 Slack 채널로 실시간 전달합니다. 회사마다 하나의 [Slack 수신 웹훅(Incoming Webhook)](https://api.slack.com/messaging/webhooks) URL을 등록하면 되고, 등록하지 않은 회사는 지금까지처럼 그냥 동작합니다(연동은 선택 사항).

- 관리자 화면(대표 전용)에 "Slack 연동" 섹션에서 웹훅 URL을 등록/수정/해제
- 활동 기록에 새 이벤트가 남을 때마다 그 메시지를 그대로 Slack으로 전송(best-effort — 실패해도 앱 동작에는 영향 없음)
- 실제 Slack API 호출은 브라우저가 아니라 서버(Edge Function)에서 수행 — Slack의 수신 웹훅 엔드포인트는 브라우저의 직접 호출(CORS)을 허용하지 않고, 웹훅 URL 자체도 클라이언트 번들에 노출시키지 않는 편이 안전합니다

## 필요한 설정 — DB 테이블 + Edge Function

Supabase SQL Editor에서 아래를 실행해주세요 (몇 번을 다시 실행해도 안전합니다).

```sql
create table if not exists company_integrations (
  company_id uuid primary key references companies(id) on delete cascade,
  slack_webhook_url text,
  updated_at timestamptz not null default now()
);

alter table company_integrations enable row level security;

drop policy if exists "members_select_company_integrations" on company_integrations;
drop policy if exists "owner_write_company_integrations" on company_integrations;

-- 웹훅 URL은 회사 구성원 누구나 조회 가능(Edge Function이 호출자 본인 권한으로
-- 조회하므로, 일반 직원의 활동도 Slack으로 전송되려면 이게 필요함) —
-- 등록/수정/해제는 대표만.
create policy "members_select_company_integrations" on company_integrations
  for select using (
    exists (
      select 1 from company_members m
      where m.company_id = company_integrations.company_id and m.user_id = auth.uid()
    )
  );
create policy "owner_write_company_integrations" on company_integrations
  for all using (
    exists (
      select 1 from companies c
      where c.id = company_integrations.company_id and c.owner_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from companies c
      where c.id = company_integrations.company_id and c.owner_id = auth.uid()
    )
  );

notify pgrst, 'reload schema';
```

그리고 `supabase/functions/notify-slack`를 Supabase 대시보드에서 배포해주세요(`docs/PHASE6_AI_EMPLOYEES.md`의 `ask-employee` 배포 방법과 동일 — 별도 시크릿 설정은 필요 없습니다, 웹훅 URL은 DB에서 조회함).

## 앱 동작

1. 대표가 관리자 화면에서 Slack 웹훅 URL을 입력하고 저장 — `SlackIntegrationRepository.saveWebhookUrl()`이 `company_integrations`에 upsert(대표만 가능, RLS로 강제)
2. `OfficeGame._logActivity()`가 이벤트를 기록할 때마다 `notifySlack` 콜백을 함께 호출(fire-and-forget, 실패해도 활동 기록 자체엔 영향 없음)
3. `AuthGate`가 그 콜백을 `SlackIntegrationRepository.notify()`에 연결 — `notify-slack` Edge Function을 호출
4. Edge Function이 호출자가 그 회사 구성원인지 확인한 뒤(회사 구성원 누구의 활동이든 전송되어야 하므로), 호출자 권한으로 `company_integrations`에서 웹훅 URL을 조회해 Slack에 POST — 웹훅이 등록 안 돼있으면 그냥 건너뜀(에러 아님)

## 이연된 범위

- 이벤트 종류별로 전송 여부를 고를 수 있는 필터(예: AI 명령만, 보드만)는 이번 범위 아님 — 지금은 활동 기록에 남는 모든 이벤트가 그대로 전송됨
- Slack 쪽에서 다시 이 앱으로 명령을 보내는 양방향 연동(Slash Command 등)은 이번 범위 아님 — 지금은 앱 → Slack 단방향
- Slack 외 다른 서비스(Notion, Discord 등) 연동은 이번 범위 아님
