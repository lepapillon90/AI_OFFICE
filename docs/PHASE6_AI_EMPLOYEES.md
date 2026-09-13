# Phase 6 (일부) — 채팅 `@멘션`: AI 직원 명령 / 귓속말

공간 채팅에서 메시지 맨 앞에 `@이름`을 붙이면 대상에 따라 동작이 달라집니다.

- `@하나 이번 주 채용 현황 정리해줘` — `하나`가 AI 직원 이름이면, 그 직원에게 보낸 **명령**으로 처리되어 실제 Anthropic API 응답이 새 메시지로 채팅에 올라옵니다.
- `@유나22 잠깐 얘기 좀` — `유나22`가 같은 공간에 있는 다른 **로그인 사용자**의 이름이면, 그 사람과 나에게만 보이는 **귓속말**로 전송됩니다.
- 둘 다 아니면 평범한 공개 메시지로 전송됩니다 (본문 그대로).

## 필요한 설정 — DB 컬럼 추가

`docs/PHASE5_MULTIPLAYER.md`의 `messages` 테이블에 귓속말/AI 답장 표시용 컬럼을 추가해야 합니다. 아래 SQL을 Supabase SQL Editor에서 실행해주세요 (몇 번을 다시 실행해도 안전합니다).

```sql
alter table messages add column if not exists to_user_id uuid references auth.users(id);
alter table messages add column if not exists to_name text;
alter table messages add column if not exists is_npc boolean not null default false;

notify pgrst, 'reload schema';
```

**주의**: 귓속말도 같은 `messages` 테이블에 저장되며, DB 자체의 읽기 권한(RLS)은 여전히 "같은 회사 구성원이면 전체 조회 가능"입니다. 화면(`ChatPanel`)에서만 대상이 아닌 사용자에게 숨겨지는 방식이라, DB에 직접 접근하면 귓속말 내용도 보일 수 있습니다 — 데모/내부용 수준의 프라이버시입니다.

## 필요한 설정 — 작업 이력·사용량 테이블 (DB 영속화)

`NpcTask`(작업 이력)와 사용량 집계를 재로그인 후에도 유지하려면 아래 SQL을 Supabase SQL Editor에서 실행해주세요 (몇 번을 다시 실행해도 안전합니다). 실행 전까지는 이 데이터가 세션 메모리에만 있다가 새로고침/재로그인 시 사라지지만, 앱 자체는 정상 동작합니다(`AuthGate`가 조회 실패를 빈 목록/빈 맵으로 처리).

```sql
create table if not exists npc_tasks (
  -- Text, not uuid: matches OfficeGame's client-generated task ids
  -- ("<epoch-micros>-task-<employeeId>"), same convention as `messages.id`.
  id text primary key,
  company_id uuid not null references companies(id) on delete cascade,
  employee_id text not null,
  command text not null,
  status text not null check (status in ('pending', 'success', 'error')),
  result text,
  error_message text,
  attempts int not null default 0,
  prompt_tokens int,
  completion_tokens int,
  total_tokens int,
  document_path text,
  created_at timestamptz not null default now()
);

alter table npc_tasks enable row level security;

drop policy if exists "members_select_npc_tasks" on npc_tasks;
drop policy if exists "members_write_npc_tasks" on npc_tasks;

create policy "members_select_npc_tasks" on npc_tasks
  for select using (
    exists (
      select 1 from company_members m
      where m.company_id = npc_tasks.company_id and m.user_id = auth.uid()
    )
  );
create policy "members_write_npc_tasks" on npc_tasks
  for all using (
    exists (
      select 1 from company_members m
      where m.company_id = npc_tasks.company_id and m.user_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from company_members m
      where m.company_id = npc_tasks.company_id and m.user_id = auth.uid()
    )
  );

create table if not exists npc_usage_events (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  employee_id text not null,
  success boolean not null,
  prompt_tokens int,
  completion_tokens int,
  created_at timestamptz not null default now()
);

alter table npc_usage_events enable row level security;

drop policy if exists "members_select_npc_usage_events" on npc_usage_events;
drop policy if exists "members_insert_npc_usage_events" on npc_usage_events;

create policy "members_select_npc_usage_events" on npc_usage_events
  for select using (
    exists (
      select 1 from company_members m
      where m.company_id = npc_usage_events.company_id and m.user_id = auth.uid()
    )
  );
create policy "members_insert_npc_usage_events" on npc_usage_events
  for insert with check (
    exists (
      select 1 from company_members m
      where m.company_id = npc_usage_events.company_id and m.user_id = auth.uid()
    )
  );

notify pgrst, 'reload schema';
```

## 필요한 설정 — 작업 문서 저장 버킷 (Supabase Storage)

AI 직원의 답변을 실제 다운로드 가능한 문서로 저장하려면(아래 "가상 문서 생성" 참고) Storage 버킷과 정책이 필요합니다. Supabase 대시보드 **Storage**에서 `npc-documents`라는 이름으로 **비공개(private)** 버킷을 하나 만들고, SQL Editor에서 아래를 실행해주세요.

```sql
insert into storage.buckets (id, name, public)
values ('npc-documents', 'npc-documents', false)
on conflict (id) do nothing;

drop policy if exists "members_read_npc_documents" on storage.objects;
drop policy if exists "members_write_npc_documents" on storage.objects;

-- Documents are stored at "<companyId>/<employeeId>/<taskId>.txt", so the
-- first path segment is the company id these policies check membership of.
create policy "members_read_npc_documents" on storage.objects
  for select using (
    bucket_id = 'npc-documents'
    and exists (
      select 1 from company_members m
      where m.user_id = auth.uid()
        and m.company_id::text = (storage.foldername(name))[1]
    )
  );
create policy "members_write_npc_documents" on storage.objects
  for insert with check (
    bucket_id = 'npc-documents'
    and exists (
      select 1 from company_members m
      where m.user_id = auth.uid()
        and m.company_id::text = (storage.foldername(name))[1]
    )
  );
```

버킷/정책을 아직 만들지 않았어도 앱은 깨지지 않습니다 — `generateDocument`가 실패하면 그 작업의 채팅 답장은 그대로 오고, "작업 이력"에 "문서 열기" 버튼만 나타나지 않습니다.

## 필요한 설정 — Edge Function 배포 (AI 직원 응답)

AI 직원이 실제로 응답하려면 OpenAI API를 호출하는 서버리스 함수가 필요합니다 (`gpt-4o-mini` 모델 사용). **API 키를 앱(클라이언트) 코드에 절대 넣으면 안 되므로** Supabase Edge Function으로 프록시합니다. 코드는 이미 `supabase/functions/ask-employee/index.ts`에 준비되어 있습니다.

> 처음엔 Anthropic API로 구현했지만, 사용자 요청으로 **OpenAI API**를 먼저 연동했습니다. 나중에 Anthropic으로 바꾸거나 두 제공자를 함께 쓰려면 이 함수를 다시 수정하면 됩니다. `AiEmployee.provider` 필드에 `'anthropic'` 값이 남아있긴 하지만, 현재 이 필드는 어떤 API를 호출할지 실제로 분기하는 데 쓰이지는 않습니다 — 모든 명령이 이 함수(현재는 OpenAI)로만 전달됩니다.

### 방법 A: Supabase 대시보드에서 배포 (CLI 설치 없이 가능)

1. [Supabase 대시보드](https://supabase.com/dashboard) → 프로젝트 선택 → 좌측 메뉴 **Edge Functions**
2. **Deploy a new function → Via Editor** → 이름을 정확히 `ask-employee`로 입력
3. 코드 편집기 내용을 전부 지우고 `supabase/functions/ask-employee/index.ts` 파일 내용을 그대로 붙여넣고 배포
4. **Edge Functions → Secrets** (또는 Project Settings → Edge Functions)에서 새 시크릿 추가:
   - Key: `OPENAI_API_KEY`
   - Value: 본인의 OpenAI API 키 ([platform.openai.com/api-keys](https://platform.openai.com/api-keys)에서 발급) — **이 값은 본인이 직접 입력해주세요**, 저는 API 키를 대신 입력해드릴 수 없습니다.
5. OpenAI 계정에 결제 수단/크레딧이 등록되어 있어야 실제 응답이 옵니다 ([platform.openai.com/settings/organization/billing](https://platform.openai.com/settings/organization/billing)).

### 방법 B: Supabase CLI로 배포

```bash
supabase functions deploy ask-employee
supabase secrets set OPENAI_API_KEY=본인의_키
```

## 앱 동작

1. `OfficeGame.sendChatMessage()`가 `@이름`을 파싱 — 같은 공간의 다른 로그인 사용자 이름과 먼저 대조(귓속말), 아니면 AI 직원 이름과 대조(명령)
2. AI 직원 명령이면 `NpcCommandService`가 `ask-employee` Edge Function을 호출하고, 응답을 그 직원 이름으로 채팅에 새 메시지로 추가(공개 메시지, 귓속말 아님)
3. 귓속말은 `ChatMessage.toUserId`가 채워진 채로 브로드캐스트·저장되고, `ChatPanel`이 발신자·수신자 본인에게만 표시
4. Edge Function이 아직 배포되지 않았거나 `OPENAI_API_KEY`가 없으면, AI 직원 명령 시 안내 메시지만 표시되고 앱은 정상 동작

## 여러 턴에 걸친 대화 맥락

`OfficeGame`이 그 직원과 이미 나눈 최근 대화(최대 6턴, `_historyFor`)를 `askEmployee`의 `history` 인자로 함께 넘기고, `NpcCommandService`·`ask-employee` Edge Function이 이를 OpenAI 요청의 `messages` 배열에 시스템 프롬프트와 새 명령 사이로 끼워 넣습니다. 히스토리는 이미 로드된 채팅 기록(`messages` 테이블)에서 그 직원과 주고받은 메시지만 걸러 만들어지므로, 로그아웃 후 재로그인해도 이어집니다. `docs/STATUS.md`에 정리된 대로 실제 OpenAI 응답이 이전 맥락을 반영하는지는 자동화 브라우저 환경 한계로 실제 클릭으로는 검증하지 못했고, `test/computer_popup_npc_chat_test.dart`의 히스토리 테스트로 코드 경로만 확인했습니다.

## 구조화된 업무 기록과 오류/재시도

- `OfficeGame.tasksFor(employee)`가 그 직원에게 보낸 명령들을 `NpcTask`(명령, 상태 pending/success/error, 결과 또는 에러 메시지, 시도 횟수) 목록으로 최근 20건까지 보관합니다 — 컴퓨터 팝업의 "작업 이력" 버튼이 이 목록을 보여줍니다.
- `askEmployee` 호출이 실패하면 한 번 자동으로 재시도하고, 그래도 실패하면 그때 비로소 직원 상태를 "오류"로 바꾸고 `NpcTask`에 시도 횟수(2)와 에러 메시지를 기록합니다. 첫 시도에서 성공하면 시도 횟수는 1로 기록됩니다.
- `npc_tasks` 테이블 마이그레이션을 실행했다면, `OfficeGame`이 생성(`pending`)·해결(`success`/`error`) 시점마다 `onTaskChanged`로 그 스냅샷을 알리고 `AuthGate`가 `NpcTaskRepository.upsertTask()`로 저장합니다(실패해도 앱은 정상 동작 — best-effort). 로그인 시 `NpcTaskRepository.fetchRecentTasks()`가 최근 200건을 불러와 `OfficeGame(initialTasks: ...)`로 복원하므로, 재로그인 후에도 "작업 이력"이 이어집니다.

## 가상 문서 생성 (실제 업무 수행)

채팅 답장만으로는 "AI 직원이 실제로 뭔가를 만들었다"는 느낌이 없어서, 명령이 성공하면 그 결과를 텍스트 문서로도 저장합니다 — 실제 OS 파일시스템에 접근하는 건 아니고, Supabase Storage의 `npc-documents` 버킷에 `<companyId>/<employeeId>/<taskId>.txt`로 업로드되는 **가상 문서**입니다.

- `OfficeGame`의 `generateDocument` 콜백(성공한 답변마다 호출)이 `NpcDocumentRepository.upload()`로 문서를 올리고 그 경로를 해당 `NpcTask.documentPath`에 기록합니다 — 채팅 답장 자체는 이 업로드가 실패해도 영향받지 않는 best-effort입니다.
- "작업 이력" 목록에서 문서가 있는 항목에 "문서 열기" 버튼이 나타나고, 누르면 `OfficeGame.documentUrlFor()`(→ `NpcDocumentRepository.signedUrl()`, 10분 유효)로 서명된 URL을 받아 새 탭으로 엽니다.
- 버킷/정책을 아직 설정하지 않았다면 문서 업로드가 조용히 실패하고 "문서 열기" 버튼이 나타나지 않을 뿐, 채팅 응답과 나머지 기능은 그대로 동작합니다.

## 사용량 추적 (호출 횟수 / 토큰)

- `ask-employee` Edge Function이 OpenAI 응답의 `usage`(`prompt_tokens`/`completion_tokens`/`total_tokens`) 필드를 그대로 함께 반환하고, `NpcCommandService.ask()`가 이를 `NpcUsage`로 파싱해 `askEmployee`의 반환값(`NpcCommandResult`)에 담습니다.
- `OfficeGame`이 직원별로 `NpcUsageSummary`(호출/성공/실패 횟수, 누적 프롬프트·응답 토큰)를 누적하며, **자동 재시도로 발생한 추가 호출도 각각 하나의 실제 API 호출로 집계**합니다 — `OfficeGame.usageFor(employee)`로 직원별, `OfficeGame.totalUsage`로 전체 합계를 조회할 수 있습니다.
- 컴퓨터 팝업이 직원 상태 아래에 "호출 N회 (성공 N · 실패 N) · N 토큰" 요약을, "작업 이력" 목록의 각 항목에는 그 호출의 토큰 수를 함께 보여줍니다.
- 실제 비용(원화/달러 환산)까지는 계산하지 않습니다 — OpenAI 대시보드에서 모델별 단가로 직접 환산해야 합니다.
- `npc_usage_events` 테이블 마이그레이션을 실행했다면, `OfficeGame`이 매 시도(재시도 포함)마다 `onUsageEvent`로 알리고 `AuthGate`가 `NpcUsageRepository.recordEvent()`로 이벤트 하나씩 저장합니다. 로그인 시 `fetchUsageSummaries()`가 그 회사의 이벤트를 모두 읽어 직원별로 집계한 뒤 `OfficeGame(initialUsage: ...)`로 복원합니다 — PostgREST에 GROUP BY가 없어 집계를 클라이언트에서 계산하는 방식이라, 이벤트가 아주 많아지면(수만 건 이상) 느려질 수 있습니다(현재 최대 5000건까지 조회).
- 자동 테스트(`test/computer_popup_npc_chat_test.dart`)로 성공/실패/재시도 각각의 집계, 여러 명령에 걸친 누적, `onTaskChanged`/`onUsageEvent`/`generateDocument`/`documentUrlFor`/초기 복원(`initialTasks`/`initialUsage`)을 모두 검증했습니다.

## 이연된 범위

- AI 직원이 외부 시스템을 실제로 조작(캘린더 등록, 다른 서비스 API 호출 등)하는 건 이번 범위 아님 — 텍스트 응답 + 가상 문서(Storage 업로드)까지만 제공
- 실제 비용(통화 환산) 계산과 사용량 상한/경고는 이번 범위 아님
- 귓속말의 DB 레벨 프라이버시(RLS)는 이번 범위 아님 — 화면에서만 숨김
