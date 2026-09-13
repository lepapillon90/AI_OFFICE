# Phase 7 — 성능·보안·배포 운영 점검

Phase 7의 마지막 항목. 새 기능을 추가하기보다, 지금까지 쌓인 코드를 성능·보안·배포 관점에서 훑어보고 실제로 고칠 수 있는 건 고쳤습니다.

## 이번에 고친 것

### 보안 — AI 직원 명령 엔드포인트가 회사 소속을 확인하지 않던 문제

`ask-employee` Edge Function은 지금까지 "로그인한 사용자인지"만 확인하고, **그 사용자가 명령을 보내는 회사의 실제 구성원인지는 확인하지 않았습니다.** (Supabase 플랫폼이 JWT 자체의 유효성은 게이트웨이 단계에서 이미 검증하므로, 위조된 토큰이 아니라 "이 프로젝트에 가입한 아무 계정"이면 통과되는 구조였습니다.) 즉, 이 앱에 가입한 사람이라면 자기 회사가 아닌 다른 회사인 척 직접 이 함수를 호출해서 대표님의 OpenAI API 키 예산을 소모시킬 수 있었습니다 — 코드 주석에도 "이건 MVP라 괜찮다"고 명시돼있던, 알고 있던 한계였습니다.

**고친 내용**: 이제 클라이언트가 `companyId`를 함께 보내고, 함수가 호출자의 JWT로 `company_members`를 조회해서 실제로 그 회사 구성원인지 확인합니다(호출자 본인 권한으로만 조회하므로 RLS를 우회하지 않음). 아닌 경우 `403`을 돌려줍니다.

### 보안/비용 — 사용량 상한(rate limit) 없음

같은 이유로, 정상적인 사용자라도 버그나 실수로 짧은 시간에 명령을 반복 전송하면 비용이 통제 없이 늘어날 수 있었습니다. 이제 같은 함수가 최근 5분간 그 회사의 실제 호출 횟수(이미 있는 `npc_usage_events` 테이블 — 재시도 포함 매 시도가 한 행)를 세어, **5분에 30회**를 넘으면 429로 거절합니다.

### 보안 — 명령/대화 맥락 길이에 서버 쪽 제한이 없었음

클라이언트(`ChatPanel`)의 `TextField`에 글자 수 제한이 아예 없었고, Edge Function도 받은 그대로 OpenAI에 전달했습니다. 앱 UI로는 문제없지만, 함수를 직접 호출하면 아주 긴 텍스트로 토큰 비용을 부풀릴 수 있었습니다.

- 클라이언트: 메시지 입력창에 1000자 제한 추가(사용성 힌트일 뿐, 진짜 방어선 아님)
- 서버: 명령은 2000자로, 대화 맥락은 턴당 2000자·최대 6턴으로 강제로 자름 — 클라이언트가 뭘 보내든 이 값이 최종 상한

### 성능 — 로그인 시 순차적으로 7번 왕복하던 문제

`AuthGate._load()`가 `companyId`를 얻은 뒤, 역할·직원 로스터·채팅 기록·작업 이력·사용량·활동 기록·업무 보드를 **하나씩 순서대로** 기다렸습니다. 이 세션에서 기능을 하나씩 추가할 때마다 로그인 대기 시간이 계속 늘어난 셈입니다. 이 7개는 서로 의존관계가 없으므로 `Future.wait`로 동시에 요청하도록 바꿨습니다 — 로그인 시간이 대략 "가장 느린 쿼리 하나" 수준으로 줄어듭니다(이전엔 7개 쿼리 시간의 합).

### 성능 — 업무 보드에 조회 상한이 없었음

`BoardRepository.fetchTasks()`가 전체 이력을 제한 없이 불러왔습니다(채팅/작업 이력/활동 기록은 이미 각각 50~200건 상한이 있었는데 보드만 빠져있었음). 회사가 오래 쓸수록 로그인마다 불러오는 카드 수가 계속 늘어나는 구조였습니다 — 최근 500건으로 상한을 뒀습니다.

### 진행 중 발견해 함께 고친 버그 — `activity_events`의 type 체크 제약

지난 커밋에서 발견해 `docs/PHASE7_ADMIN.md`에 이미 반영했습니다: `activity_events.type` 체크 제약이 `'board'`/`'meeting'` 값을 허용하지 않아서, 그 SQL을 먼저 실행한 사용자는 업무 보드·회의 활동 기록 저장이 조용히 실패하고 있었을 것입니다.

## 재배포 후 라이브 테스트로 발견해 고친 버그

실제로 재배포하고 관리자 계정으로 호출해보니, 정상적인 요청까지 `500 Internal Server Error`(`"JSON object requested, multiple (or no) rows returned"`)로 실패했습니다. 원인: 소속 확인 쿼리가 `.maybeSingle()`을 썼는데, **대표(owner)는 `owner_manage_members` 정책 덕분에 자기 회사의 모든 구성원 행을 볼 수 있어서** 구성원이 2명 이상인 회사의 대표가 호출하면 여러 행이 반환되어 `.maybeSingle()`이 에러를 던졌습니다(인사관리자/일반 직원은 자기 자신의 행만 보이는 `self_select_membership` 정책만 적용돼서 이 문제가 없었음 — 그래서 소속 확인 자체가 통과되는 owner 계정으로 테스트할 때만 걸림). `.limit(1)` + 길이 확인으로 바꿔서 고쳤습니다 — **이 수정본으로 다시 한번 재배포가 필요합니다.**

## 필요한 설정

**Edge Function 재배포 필수** — `supabase/functions/ask-employee/index.ts`가 바뀌었으므로 Supabase 대시보드에서 다시 배포해주세요(`docs/PHASE6_AI_EMPLOYEES.md`의 배포 방법과 동일). 재배포 전까지는 클라이언트가 `companyId`를 보내지만 예전 함수가 그 필드를 그냥 무시할 뿐이라 앱은 정상 동작합니다 — 다만 이번에 고친 소속 확인/사용량 상한은 재배포 전까지는 적용되지 않습니다.

새 DB 마이그레이션은 없습니다 — 기존 테이블(`company_members`, `npc_usage_events`)을 그대로 조회만 합니다.

## 후속 반영 — 위 권장 사항 중 구현한 것

아래는 위 "권장 사항"으로 남겨뒀던 항목 중 이후 실제로 반영한 것입니다.

### 비용 환산 — AI 직원 사용량을 USD로 표시

`ask-employee`가 매 호출마다 돌려주는 프롬프트/완료 토큰 수(`NpcUsage`)에, 이 함수가 쓰는 모델(`gpt-4o-mini`)의 공개 단가를 곱해 대략적인 USD 비용을 계산합니다(`lib/game/npc/npc_usage.dart`의 `estimatedCostUsd`/`formatUsd`). 컴퓨터 팝업의 직원별 누적 사용량과 작업별 사용량 옆에 "약 $0.0012"처럼 표시됩니다. 단가는 이 글을 쓴 시점 기준이라 실제 예산 산정에 쓰려면 최신 단가를 다시 확인해야 합니다 — OpenAI가 가격을 바꿔도 자동으로 반영되지 않습니다.

### 사용량 상한 알림 — 429 응답을 재시도 없이 구분해서 표시

`ask-employee`가 사용량 상한(5분에 30회)으로 429를 돌려주면, 클라이언트가 이를 일반 오류와 구분합니다(`AskEmployeeRateLimitException`, `lib/game/npc/npc_command_errors.dart`). 지금까지는 어떤 실패든 "재시도 후에도 실패" 문구로 뭉뚱그려지고 한 번 재시도까지 했는데, 한도 초과는 **재시도해도 다시 거절될 뿐이므로** 즉시 멈추고 함수가 보낸 메시지("이 회사의 AI 직원 호출 한도를 초과했습니다...")를 그대로 채팅/작업 이력/활동 기록에 남깁니다. 한도 초과로 끝난 시도는 실제 OpenAI 호출이 없었으므로 사용량 집계(`npc_usage_events`)에도 카운트하지 않습니다.

### 웹 렌더러 — 이미 CanvasKit으로 고정돼있음을 확인

이 프로젝트가 쓰는 Flutter 3.47.4에서 `flutter build web --help`를 직접 확인해보니, 예전 버전에 있던 `--web-renderer`(auto/html/canvaskit 선택) 플래그가 이제 없습니다 — 최근 Flutter는 `flutter build web`의 기본이자 유일한 렌더러가 CanvasKit이고, 대신 WebAssembly로 컴파일하는 `--wasm` 옵션(아직 실험적, 브라우저 WASM GC 지원 필요)만 별도로 존재합니다. 즉 "권장 사항"으로 남겨뒀던 "Flame 그래픽에 CanvasKit이 유리할 수 있다"는 이미 기본값으로 충족돼있어서, `scripts/vercel_build.sh`나 `web/index.html`을 바꿀 필요가 없었습니다. `--wasm`으로 전환하는 건 별도의 실제 성능 비교가 필요한 선택이라 이번 범위에 넣지 않습니다.

### Realtime 채널 접근 제어 — 회사 ID만 알면 구독 가능하던 문제

`MultiplayerChannel`이 만드는 `office:company:<companyId>` 채널을 Supabase의 "Realtime Authorization" 기능으로 잠갔습니다. 클라이언트가 `RealtimeChannelConfig(private: true)`로 채널을 열면, Supabase가 구독/브로드캐스트/presence 트래킹 전에 서버 쪽 `realtime.messages` 테이블의 RLS 정책으로 그 채널 토픽에 대한 접근을 허가하는지 확인합니다 — 즉 지금까지처럼 `companyId` UUID만 알면 누구나 구독할 수 있던 것과 달리, **그 회사의 실제 구성원(`company_members`)만** 채널을 열 수 있게 됩니다.

**추가 SQL** (Supabase SQL Editor에서 실행, 여러 번 실행해도 안전):

```sql
-- realtime.messages는 이미 Supabase가 RLS를 켜둔 테이블이고 소유자가
-- supabase_realtime_admin이라, 일반 프로젝트 role로는
-- `alter table ... enable row level security`를 실행할 권한이 없습니다
-- (42501: must be owner of table messages). RLS는 이미 켜져있으므로
-- 정책만 추가하면 됩니다.
drop policy if exists "company_members_realtime_office" on realtime.messages;

-- office:company:<companyId> 토픽만 다룸 — 세 번째 ':' 구분 필드가 companyId.
-- realtime.topic()은 클라이언트가 channel()에 넘긴 이름 그대로이므로, 이 앱이
-- 쓰는 이름 규칙과 정확히 맞아야 함 (lib/data/multiplayer_channel.dart 참고).
create policy "company_members_realtime_office" on realtime.messages
  for all
  using (
    split_part(realtime.topic(), ':', 1) = 'office'
    and exists (
      select 1 from company_members m
      where m.user_id = auth.uid()
        and m.company_id::text = split_part(realtime.topic(), ':', 3)
    )
  )
  with check (
    split_part(realtime.topic(), ':', 1) = 'office'
    and exists (
      select 1 from company_members m
      where m.user_id = auth.uid()
        and m.company_id::text = split_part(realtime.topic(), ':', 3)
    )
  );
```

**주의**: 이 SQL을 실행하고 클라이언트가 재배포된 뒤에는, `company_members`에 없는 사용자는 그 회사의 `office:company:<companyId>` 채널을 아예 구독할 수 없습니다 — 프론트/백엔드가 같이 바뀌어야 하는 변경이라, 순서가 어긋나면(SQL만 먼저 실행하고 예전 클라이언트가 아직 `private: true` 없이 붙어있는 경우 등) 정상 동작에 영향은 없습니다(예전 클라이언트는 여전히 공개 채널로 붙으므로). 반대로 새 클라이언트가 먼저 배포되고 이 SQL이 아직 실행 안 됐다면, `private: true` 채널이 RLS 정책 없이는 아무도(정당한 구성원 포함) 구독하지 못해 실시간 동기화가 전부 끊깁니다 — **반드시 이 SQL을 먼저 실행한 뒤에 새 클라이언트를 배포/새로고침해주세요.**

### 감사 기록 — 표시 이름 외에 안정적인 사용자 ID도 기록

`activity_events`에 `actor_user_id` 컬럼을 추가하고, 이벤트를 기록하는 시점의 로그인 세션(`multiplayer.userId`)을 함께 저장합니다(`ActivityEvent.actorUserId`). 기존 `actor_name`은 "직원 정보 관리"에서 바꿀 수 있는 표시 이름이라 시간이 지나면 실제 계정과 어긋날 수 있는데, `actor_user_id`는 Supabase Auth의 고정 ID라 바뀌지 않습니다. 지금 UI에는 아직 노출하지 않고 값만 쌓아두는 단계입니다 — 나중에 실제 감사 도구가 필요해지면 이 컬럼으로 계정을 추적할 수 있습니다.

**추가 SQL** (Supabase SQL Editor에서 실행, 여러 번 실행해도 안전):

```sql
alter table activity_events add column if not exists actor_user_id uuid;
```

새 컬럼일 뿐 RLS 정책 변경은 없습니다 — 기존 `activity_events` 정책이 행 전체(모든 컬럼)에 대해 이미 적용됩니다.

## 점검했지만 지금 당장 고치지 않은 것 (권장 사항)

실제로 검증하지 못한 채 프로덕션 동작을 바꾸는 위험을 피하려고, 아래는 **문제 진단 + 권장안**만 남겨둡니다.

- **Vercel 빌드가 매번 Flutter SDK를 새로 클론**: `scripts/vercel_build.sh`가 캐시 없이 매 배포마다 Flutter stable을 얕은 클론합니다 — 빌드 시간과 GitHub 가용성에 의존적입니다. Vercel 프로젝트 설정에서 빌드 캐시(예: `flutter/` 디렉터리)를 구성하면 개선할 수 있지만, Vercel 대시보드 설정이 필요해 코드만으로는 확인할 수 없어 이번 범위에서는 의도적으로 제외합니다.

## 이연된 범위

- 부하 테스트/실제 트래픽 기반 성능 측정은 하지 않음 — 코드 리뷰 기반 점검
- CSP(Content-Security-Policy) 헤더, HSTS 등 HTTP 보안 헤더 설정은 Vercel 쪽 설정이 필요해 이번 범위 아님
- 의존성 취약점 스캔(예: `flutter pub outdated`가 알려주는 것 이상의 CVE 점검)은 이번 범위 아님
