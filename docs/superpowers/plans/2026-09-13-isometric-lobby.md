# Isometric Lobby Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace only the first-floor lobby with a 2.5D isometric diorama while preserving movement, collision boundaries, elevator travel, and existing overlays.

**Architecture:** Keep movement, collision, and the existing screen-coordinate world exactly as they are. Render the lobby as independent world-level image components whose priorities are derived from their foot-point Y coordinate; calculate the same priority for the player and lobby NPCs. `OfficeGame` chooses this component set only for `Floor.lobby`; floors 2–4 retain their current map components.

**Tech Stack:** Flutter, Flame, Flutter test, project image assets generated with the built-in ImageGen workflow.

**Spec:** `docs/superpowers/specs/2026-09-13-isometric-lobby-design.md`

## Global Constraints

- Convert only `Floor.lobby`; keep floors 2–4 on their existing top-down components.
- Do not change Supabase authentication, employee persistence, or the public interaction-overlay APIs.
- Use the existing world-coordinate collision checks; the isometric effect comes from layered artwork and Y-based depth only.
- Create all project image assets inside `assets/images/office_1f/isometric/` and register that directory in `pubspec.yaml`.
- Preserve `FloorLayouts.lobby.arrivalPosition` semantics so elevator travel continues to place the player next to the elevator.
- Execute `flutter test` and inspect a web screenshot before declaring the feature complete.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `lib/game/isometric/iso_projection.dart` | Converts a world foot-point Y coordinate into a stable depth priority. |
| `lib/game/isometric/iso_lobby_layout.dart` | Owns 1층 dimensions, collision rectangles, elevator coordinate, and fixed asset placements. |
| `lib/game/isometric/iso_lobby_scene.dart` | Builds independent Flame components for the ground, each furniture object, and the foreground. |
| `lib/game/office_game.dart` | Selects the isometric scene for `Floor.lobby` and refreshes dynamic character priorities. |
| `lib/game/player/office_player.dart` | Allows `OfficeGame` to update the player’s draw priority without changing its movement rules. |
| `lib/game/npc/npc_component.dart` | Allows lobby NPCs to receive the same depth priority policy. |
| `assets/images/office_1f/isometric/*.png` | Layered 1층 isometric artwork consumed by the scene. |
| `test/iso_projection_test.dart` | Verifies coordinate projection and deterministic depth ordering. |
| `test/iso_lobby_layout_test.dart` | Verifies lobby collision and elevator-arrival data. |
| `test/iso_lobby_scene_test.dart` | Verifies scene component count, asset paths, and depth priorities. |
| `test/floor_change_test.dart` | Extends floor-change coverage to validate the isometric first floor. |

### Task 1: Depth Policy

**Files:**
- Create: `lib/game/isometric/iso_projection.dart`
- Create: `test/iso_projection_test.dart`

**Interfaces:**
- Produces: `int IsoProjection.priorityFor(Vector2 worldFootPoint, {int layerOffset = 0})`.
- Consumes: Flame `Vector2` only; it must not read game state or load assets.

- [ ] **Step 1: Write the failing projection and depth tests**

```dart
import 'package:ai_office/game/isometric/iso_projection.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('orders objects by foot-point Y then layer offset', () {
    final back = IsoProjection.priorityFor(Vector2(96, 64));
    final front = IsoProjection.priorityFor(Vector2(96, 160));

    expect(front, greaterThan(back));
    expect(IsoProjection.priorityFor(Vector2(96, 160), layerOffset: 10), front + 10);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/iso_projection_test.dart`

Expected: compilation failure because `IsoProjection` does not exist.

- [ ] **Step 3: Implement the pure projection utility**

```dart
import 'package:flame/components.dart';

abstract final class IsoProjection {
  static const _priorityScale = 100;

  static int priorityFor(Vector2 worldFootPoint, {int layerOffset = 0}) =>
      (worldFootPoint.y * _priorityScale).round() + layerOffset;
}
```

- [ ] **Step 4: Run the projection test to verify it passes**

Run: `flutter test test/iso_projection_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit the independently tested utility**

```bash
git add lib/game/isometric/iso_projection.dart test/iso_projection_test.dart
git commit -m "feat: add isometric projection policy"
```

### Task 2: 1층 Data and Layered Artwork

**Files:**
- Create: `lib/game/isometric/iso_lobby_layout.dart`
- Create: `assets/images/office_1f/isometric/lobby_ground.png`
- Create: `assets/images/office_1f/isometric/reception.png`
- Create: `assets/images/office_1f/isometric/cafe.png`
- Create: `assets/images/office_1f/isometric/store.png`
- Create: `assets/images/office_1f/isometric/lounge.png`
- Create: `assets/images/office_1f/isometric/planters.png`
- Create: `assets/images/office_1f/isometric/foreground.png`
- Modify: `pubspec.yaml`
- Create: `test/iso_lobby_layout_test.dart`

**Interfaces:**
- Produces: `IsoLobbyLayout.floorLayout` as a `FloorLayout`.
- Produces: `IsoLobbyLayout.placements` as `List<IsoLobbyPlacement>`.
- Produces: `IsoLobbyPlacement({required String assetPath, required Vector2 worldFootPoint, required Vector2 screenSize, int layerOffset = 0})`.
- Consumes: `IsoProjection.priorityFor` in later scene construction.

- [ ] **Step 1: Write the failing data tests**

```dart
import 'package:ai_office/game/isometric/iso_lobby_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps the elevator arrival point inside the isometric lobby', () {
    final layout = IsoLobbyLayout.floorLayout;

    expect(layout.arrivalPosition.x, inInclusiveRange(0, layout.worldSize.x));
    expect(layout.arrivalPosition.y, inInclusiveRange(0, layout.worldSize.y));
  });

  test('declares independent ground, furniture, and foreground assets', () {
    final paths = IsoLobbyLayout.placements.map((item) => item.assetPath);

    expect(paths, contains('office_1f/isometric/lobby_ground.png'));
    expect(paths, contains('office_1f/isometric/reception.png'));
    expect(paths, contains('office_1f/isometric/foreground.png'));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/iso_lobby_layout_test.dart`

Expected: compilation failure because `IsoLobbyLayout` does not exist.

- [ ] **Step 3: Generate and inspect the seven layered assets**

Use the built-in ImageGen editing workflow with `C:\Users\suhye\OneDrive\바탕 화면\오피스\1층.png` as the style and composition reference. Generate one image per listed asset, preserving the warm pixel-art/isometric office style and using no unreadable embedded text. Ground contains only walkable floor and exterior background; furniture assets contain transparent space around their object group; `foreground.png` contains only front railings, plants, and entrance decoration. Inspect each output, copy the selected PNG into `assets/images/office_1f/isometric/`, and add:

```yaml
flutter:
  assets:
    - assets/images/office_1f/isometric/
```

- [ ] **Step 4: Implement the fixed lobby coordinate data**

```dart
class IsoLobbyPlacement {
  const IsoLobbyPlacement({
    required this.assetPath,
    required this.worldFootPoint,
    required this.screenSize,
    this.layerOffset = 0,
  });

  final String assetPath;
  final Vector2 worldFootPoint;
  final Vector2 screenSize;
  final int layerOffset;
}

abstract final class IsoLobbyLayout {
  static final floorLayout = FloorLayout(
    worldSize: Vector2(960, 704),
    elevatorPosition: Vector2(480, 128),
    blockers: [
      ...FloorLayout.perimeterWalls(Vector2(960, 704)),
      const Rect.fromLTWH(400, 192, 160, 96),
      const Rect.fromLTWH(96, 320, 240, 224),
      const Rect.fromLTWH(624, 320, 240, 192),
    ],
  );

  static final placements = <IsoLobbyPlacement>[
    IsoLobbyPlacement(assetPath: 'office_1f/isometric/lobby_ground.png', worldFootPoint: Vector2.zero(), screenSize: Vector2(1536, 1024), layerOffset: -100000),
    IsoLobbyPlacement(assetPath: 'office_1f/isometric/reception.png', worldFootPoint: Vector2(480, 224), screenSize: Vector2(320, 230)),
    IsoLobbyPlacement(assetPath: 'office_1f/isometric/cafe.png', worldFootPoint: Vector2(208, 432), screenSize: Vector2(430, 350)),
    IsoLobbyPlacement(assetPath: 'office_1f/isometric/store.png', worldFootPoint: Vector2(752, 400), screenSize: Vector2(390, 300)),
    IsoLobbyPlacement(assetPath: 'office_1f/isometric/lounge.png', worldFootPoint: Vector2(736, 544), screenSize: Vector2(350, 250)),
    IsoLobbyPlacement(assetPath: 'office_1f/isometric/planters.png', worldFootPoint: Vector2(480, 416), screenSize: Vector2(300, 260)),
    IsoLobbyPlacement(assetPath: 'office_1f/isometric/foreground.png', worldFootPoint: Vector2(480, 672), screenSize: Vector2(1536, 250), layerOffset: 100000),
  ];
}
```

- [ ] **Step 5: Run the data test to verify it passes**

Run: `flutter test test/iso_lobby_layout_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit data and assets**

```bash
git add pubspec.yaml lib/game/isometric/iso_lobby_layout.dart test/iso_lobby_layout_test.dart assets/images/office_1f/isometric/
git commit -m "feat: add isometric lobby layout assets"
```

### Task 3: Isometric Scene Components and Dynamic Character Depth

**Files:**
- Create: `lib/game/isometric/iso_lobby_scene.dart`
- Modify: `lib/game/player/office_player.dart`
- Modify: `lib/game/npc/npc_component.dart`
- Create: `test/iso_lobby_scene_test.dart`

**Interfaces:**
- Produces: `List<Component> IsoLobbyScene.createComponents()`; each component is a world-level sibling with its own priority.
- Produces: `void OfficePlayer.setRenderPriority(int value)`.
- Produces: `void NpcComponent.setRenderPriority(int value)`.
- Consumes: `IsoLobbyLayout.placements` and `IsoProjection`.

- [ ] **Step 1: Write failing scene and character-depth tests**

```dart
import 'package:ai_office/game/isometric/iso_lobby_scene.dart';
import 'package:ai_office/game/isometric/iso_projection.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates a world component for every declared lobby placement', () {
    expect(IsoLobbyScene.createComponents(), hasLength(7));
  });

  test('uses each placement foot point to set its component priority', () {
    final components = IsoLobbyScene.createComponents();
    expect(components.first.priority, lessThan(components.last.priority));
    expect(components.last.priority, greaterThan(IsoProjection.priorityFor(Vector2(480, 672))));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/iso_lobby_scene_test.dart`

Expected: compilation failure because `IsoLobbyScene` does not exist.

- [ ] **Step 3: Implement root-level scene components**

```dart
abstract final class IsoLobbyScene {
  static List<Component> createComponents() => IsoLobbyLayout.placements
      .map(IsoLobbySpriteComponent.new)
      .toList();
}

class IsoLobbySpriteComponent extends SpriteComponent {
  IsoLobbySpriteComponent(this.placement)
      : super(
          position: placement.worldFootPoint,
          size: placement.screenSize,
          anchor: Anchor.bottomCenter,
          priority: IsoProjection.priorityFor(
            placement.worldFootPoint,
            layerOffset: placement.layerOffset,
          ),
        );

  final IsoLobbyPlacement placement;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await Sprite.load(placement.assetPath);
  }
}
```

Add the following public method to both character components:

```dart
void setRenderPriority(int value) => priority = value;
```

- [ ] **Step 4: Run the scene test to verify it passes**

Run: `flutter test test/iso_lobby_scene_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit the scene layer**

```bash
git add lib/game/isometric/iso_lobby_scene.dart lib/game/player/office_player.dart lib/game/npc/npc_component.dart test/iso_lobby_scene_test.dart
git commit -m "feat: add depth-sorted isometric lobby scene"
```

### Task 4: Integrate 1층 Without Regressing Other Floors

**Files:**
- Modify: `lib/game/floors/floor_layout.dart`
- Modify: `lib/game/office_game.dart`
- Modify: `test/floor_change_test.dart`

**Interfaces:**
- Consumes: `IsoLobbyLayout.floorLayout`, `IsoLobbyScene.createComponents()`, and `IsoProjection.priorityFor`.
- Produces: 1층 selected through the existing `changeFloor(Floor.lobby)` method with all other floor behavior unchanged.

- [ ] **Step 1: Write failing floor integration tests**

```dart
test('uses the isometric first-floor world and elevator location', () {
  expect(FloorLayouts.lobby.worldSize, IsoLobbyLayout.floorLayout.worldSize);
  expect(FloorLayouts.lobby.elevatorPosition, IsoLobbyLayout.floorLayout.elevatorPosition);
});

testWidgets('switching to the first floor keeps the player near its elevator', (tester) async {
  final game = OfficeGame.forTest(playerPosition: Vector2(430, 350));
  await tester.pumpWidget(MaterialApp(home: OfficeScreen(game: game)));
  await tester.runAsync(() => game.changeFloor(Floor.lobby));
  await tester.pump();

  expect(game.currentFloor, Floor.lobby);
  expect(game.player.position, IsoLobbyLayout.floorLayout.arrivalPosition);
  expect(game.isElevatorNearby, isTrue);
});
```

- [ ] **Step 2: Run the floor integration test to verify it fails**

Run: `flutter test test/floor_change_test.dart`

Expected: failure because the old 640×448 lobby layout is still selected.

- [ ] **Step 3: Connect the isometric lobby to `OfficeGame`**

Replace `FloorLayouts.lobby` with `IsoLobbyLayout.floorLayout`. In `OfficeGame._`, replace the lobby entry with `IsoLobbyScene.createComponents()`. On every `_onPlayerMoved` call while `currentFloor == Floor.lobby`, call:

```dart
player.setRenderPriority(IsoProjection.priorityFor(player.position));
for (final npc in _npcsByWorkstation.values) {
  npc.setRenderPriority(IsoProjection.priorityFor(npc.position));
}
elevator.priority = IsoProjection.priorityFor(elevator.position);
```

Retain the existing workspace computer proximity branch exactly: computers remain workspace-only, and moving to the lobby clears a previously nearby computer.

- [ ] **Step 4: Run all automated tests**

Run: `flutter test`

Expected: PASS, including existing computer, office layout, player movement, and floor-change tests.

- [ ] **Step 5: Complete visual QA in a web browser**

Run: `flutter run -d chrome --web-port 8765`

Check: first-floor ground fills the camera bounds; the player moves around the reception/cafe/store blockers; player priority changes relative to reception and foreground layers; `E` at the elevator opens the floor selector; floors 2–4 still open; no missing-asset checkerboards or console errors appear. Capture a screenshot and inspect the image directly.

- [ ] **Step 6: Commit the integrated vertical slice**

```bash
git add lib/game/floors/floor_layout.dart lib/game/office_game.dart test/floor_change_test.dart
git commit -m "feat: render first floor as isometric lobby"
```

## Plan Self-Review

- Spec coverage: Tasks 1–3 implement Y-based depth, layered rendering, asset isolation, and depth ordering. Task 2 provides dedicated collision and interaction coordinates. Task 4 preserves elevator behavior, workspace-only computer state, camera bounds, and verifies floors 2–4 remain available.
- Placeholder scan: no `TODO`, `TBD`, or deferred implementation steps remain. The async loader note specifies the required `onLoad` behavior rather than leaving an asset-loading decision open.
- Type consistency: every later task consumes the `IsoProjection`, `IsoLobbyLayout`, `IsoLobbyPlacement`, `IsoLobbyScene`, and `setRenderPriority` interfaces defined by earlier tasks.
