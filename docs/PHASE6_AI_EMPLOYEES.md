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
4. Edge Function이 아직 배포되지 않았거나 `ANTHROPIC_API_KEY`가 없으면, AI 직원 명령 시 안내 메시지만 표시되고 앱은 정상 동작

## 이연된 범위

- AI 직원의 실제 업무 수행(파일 생성, 외부 도구 호출 등)은 이번 범위 아님 — 텍스트 응답만 제공
- 대화 맥락(이전 메시지 기억)은 없음 — 매 명령이 독립적으로 처리됨
- 귓속말의 DB 레벨 프라이버시(RLS)는 이번 범위 아님 — 화면에서만 숨김
