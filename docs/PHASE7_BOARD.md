# Phase 7 (일부) — 프로젝트·업무 보드

할 일 / 진행 중 / 완료 세 칸짜리 칸반 보드입니다. 카드를 AI 직원에게 배정하면, "AI에게 지시" 버튼으로 그 직원의 채팅방에 카드 제목을 `@직원이름 제목` 명령으로 바로 보낼 수 있습니다(기존 채팅 `@멘션` 파이프라인 그대로 재사용, `docs/PHASE6_AI_EMPLOYEES.md`). 화면 우측 상단의 보드(칸반) 아이콘으로 엽니다.

## 필요한 설정 — DB 테이블 추가

재로그인 후에도 보드가 유지되려면 아래 SQL을 Supabase SQL Editor에서 실행해주세요 (몇 번을 다시 실행해도 안전합니다). 실행 전에는 보드가 세션 메모리에만 있다가 새로고침 시 사라지지만, 앱 자체는 정상 동작합니다.

```sql
create table if not exists board_tasks (
  -- Text, not uuid: matches OfficeGame's client-generated task ids
  -- ("<epoch-micros>-board"), same convention as `messages.id`.
  id text primary key,
  company_id uuid not null references companies(id) on delete cascade,
  title text not null,
  description text,
  status text not null check (status in ('todo', 'in_progress', 'done')),
  assignee_id text,
  assignee_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table board_tasks enable row level security;

drop policy if exists "members_select_board_tasks" on board_tasks;
drop policy if exists "members_write_board_tasks" on board_tasks;
drop policy if exists "members_delete_board_tasks" on board_tasks;

create policy "members_select_board_tasks" on board_tasks
  for select using (
    exists (
      select 1 from company_members m
      where m.company_id = board_tasks.company_id and m.user_id = auth.uid()
    )
  );
create policy "members_write_board_tasks" on board_tasks
  for insert with check (
    exists (
      select 1 from company_members m
      where m.company_id = board_tasks.company_id and m.user_id = auth.uid()
    )
  );
create policy "members_update_board_tasks" on board_tasks
  for update using (
    exists (
      select 1 from company_members m
      where m.company_id = board_tasks.company_id and m.user_id = auth.uid()
    )
  );
create policy "members_delete_board_tasks" on board_tasks
  for delete using (
    exists (
      select 1 from company_members m
      where m.company_id = board_tasks.company_id and m.user_id = auth.uid()
    )
  );

notify pgrst, 'reload schema';
```

## 앱 동작

1. `OfficeGame.createBoardTask()`/`moveBoardTask()`/`assignBoardTask()`/`deleteBoardTask()`가 보드를 메모리에서 바꾸고, `onBoardTaskChanged`/`onBoardTaskDeleted` 콜백으로 `AuthGate`에 알림 → `BoardRepository`가 Supabase에 반영(best-effort)
2. 로그인 시 `BoardRepository.fetchTasks()`가 전체 카드를 불러와 `OfficeGame(initialBoardTasks: ...)`로 복원
3. 카드 생성/이동/배정/삭제/설명 수정은 모두 `docs/PHASE7_ACTIVITY.md`의 활동 기록에도 함께 남음(`ActivityType.board`)
4. "AI에게 지시" 버튼은 담당자가 있는 카드에서만 나타나며, `OfficeGame.dispatchBoardTaskToAssignee()`가 그 직원과의 채팅방을 열고 카드 제목을 명령으로 전송 — 이후 흐름은 일반 `@멘션` 명령과 동일(재시도/작업 이력/사용량 집계 모두 적용됨)
5. 카드는 "이전/다음 단계로" 버튼(한 칸씩) 또는 **드래그 앤 드롭**(원하는 칸으로 바로) 둘 다로 옮길 수 있음 — 각 카드가 `Draggable<String>`(카드 id를 실어 나름), 각 칸이 `DragTarget<String>`으로, 드롭되면 `OfficeGame.setBoardTaskStatus()`가 그 칸으로 바로 이동시킴(중간 칸을 거치지 않음). 드래그 중인 칸은 살짝 투명해지고, 카드를 올리고 있는 칸은 옅게 강조됨

## 카드 설명(description) 편집

각 카드의 편집 아이콘(연필+메모)으로 여러 줄 설명을 입력·수정·삭제(빈 값으로 저장하면 삭제)할 수 있습니다 — `OfficeGame.editBoardTaskDescription()`. 카드에는 최대 2줄까지 미리보기로 표시됩니다.

## 이연된 범위

- 담당자는 AI 직원만 지정 가능 — 사람(팀원)에게 배정하는 기능은 이번 범위 아님
- 여러 사용자가 동시에 보드를 볼 때 실시간 동기화(Realtime 구독)는 이번 범위 아님 — 각자 로그인 시점 스냅샷만 봄

## 검증 기록 (드래그 앤 드롭)

- `OfficeGame.setBoardTaskStatus()` 자체는 `test/board_test.dart`로 검증
- "새 업무" 다이얼로그의 제목 입력 시 "추가" 버튼이 계속 비활성 상태로 멈춰있던 실제 버그(`TextField`에 `onChanged`가 없어서 다이얼로그가 다시 빌드되지 않던 것)를 이번에 라이브 브라우저 확인 중 발견해 함께 고침 — `test/board_panel_test.dart`에 회귀 테스트 추가
- 드래그 앤 드롭 자체는 실제 실행 중인 앱에서 라이브로 확인(정상적으로 "완료" 칸으로 이동, 활동 기록에도 남음) — 다만 `WidgetTester`로 Flutter의 `Draggable`/`DragTarget` 제스처 아레나를 자동 재현하는 위젯 테스트는 이 세션에서 불안정하게 나와 포함하지 않음(기능 자체의 문제가 아니라 테스트 하네스에서 제스처 경쟁을 재현하기 까다로운 것으로 보임)
