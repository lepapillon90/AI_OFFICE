# 1층 에셋 기반 레이아웃 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 제공된 1층 에셋 시트로 28×18 타일(1792×1152px) 로비를 참조 이미지와 가깝게 구현한다.

**Architecture:** 원본 시트는 `assets/1층`에 유지하고, 게임용 PNG만 `assets/images/office_1f/v4/`에 분리한다. 바닥, 구조물, 가구, 브랜딩, 입구 조경 순서로 렌더링한다.

**Tech Stack:** Flutter Web, Flame, Dart, PNG sprite assets.

**Spec:** `docs/superpowers/specs/2026-09-14-first-floor-asset-layout-design.md`

## Global Constraints

- 맵은 28×18, 타일은 64px, 세계 크기는 1792×1152px다.
- `assets/1층` 에셋 시트에서만 요소를 분리한다.
- 로그인·채팅·AI 직원·다른 층은 변경하지 않는다.
- 이번 단계에는 가구 충돌·NPC·상호작용을 넣지 않는다.
- 각 단계는 화면 스크린샷 QA 후 커밋한다.

### Task 1: 28×18 바닥 규격 확정

**Files:** `lib/game/isometric/iso_lobby_layout.dart`, `test/iso_lobby_layout_test.dart`

- [ ] `worldSize == Vector2(1792, 1152)` 및 바닥 배치 수가 504개인지 확인하는 실패 테스트를 작성한다.
- [ ] 해당 테스트가 기존 24×16 규격 때문에 실패하는지 확인한다.
- [ ] 열·행을 28·18로 바꾸고, 카페(좌측), 중앙 광장, 매점·라운지(우측), 입구(하단 중앙)의 바닥 구역을 확보한다.
- [ ] 바닥 테스트 통과를 확인하고 이 단계만 커밋한다.

### Task 2: 에셋 시트 분리와 등록

**Files:** `assets/images/office_1f/v4/{structure,lobby,cafe,store,branding,entrance}/`, `lib/game/isometric/first_floor_asset_manifest.dart`, `test/first_floor_asset_manifest_test.dart`, `pubspec.yaml`

- [ ] 엘리베이터, 중앙 나무 화단, 카페 카운터, 매점 선반, 유리 출입구가 manifest에 포함되는 실패 테스트를 작성한다.
- [ ] manifest 부재로 테스트가 실패하는 것을 확인한다.
- [ ] 원본 시트를 수정하지 않고 구조물·로비·카페·매점·브랜딩·입구 요소를 개별 PNG로 분리한다.
- [ ] Flutter 자산 목록과 manifest를 추가하고 테스트 통과를 확인한 뒤 커밋한다.

### Task 3: 참조 이미지형 에셋 배치

**Files:** `lib/game/isometric/first_floor_asset_layout.dart`, `lib/game/isometric/first_floor_asset_component.dart`, `test/first_floor_asset_layout_test.dart`, `lib/game/isometric/iso_lobby_scene.dart`, `test/iso_lobby_scene_test.dart`

- [ ] 상단 로비, 카페, 중앙 광장, 매점, 라운지, 입구·조경 여섯 구역이 존재하는 실패 테스트를 작성한다.
- [ ] layout 부재로 테스트가 실패하는 것을 확인한다.
- [ ] 상단은 브랜딩·리셉션·엘리베이터·계단, 좌측은 카페, 중앙은 나무 화단, 우측은 매점·라운지, 하단은 유리 출입구·연못·화단으로 배치한다.
- [ ] 고유 PNG를 한 번만 로드하는 Flame 컴포넌트를 만들고 바닥 다음 레이어로 연결한다.
- [ ] 레이아웃·씬 테스트 통과를 확인하고 커밋한다.

### Task 4: 화면 QA와 배치 보정

**Files:** `docs/qa/first-floor-asset-layout.png`, `lib/game/isometric/first_floor_asset_layout.dart`, `docs/STATUS.md`

- [ ] 웹에서 1층을 실행하고 전체 화면을 캡처한다.
- [ ] 중앙 화단 통로, 카페·매점 앞 공간, 출입구·연못, 요소 겹침과 잘림을 직접 확인한다.
- [ ] 좌표·크기만 보정하고 관련 바닥·manifest·layout·씬·층 이동 테스트를 실행한다.
- [ ] QA 이미지와 상태 문서를 커밋한다.
