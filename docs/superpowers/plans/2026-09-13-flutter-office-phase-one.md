# Flutter Office Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Flutter Web and Flame pixel-office demo where one player moves with the keyboard, is camera-followed, and cannot cross walls or desks.

**Architecture:** `OfficeGame` owns the Flame world and camera. `OfficeMap` creates visual tiles and exposes fixed collision rectangles; `OfficePlayer` owns keyboard movement and clamps its hitbox against those rectangles. Flutter's `GameWidget` hosts the game and keeps non-game UI out of the game layer.

**Tech Stack:** Flutter Web, Dart, Flame, flutter_test, generated PNG assets.

**Spec:** `docs/DESIGN.md`

## Global Constraints

- Target Flutter Web first.
- Use Flame only for the virtual-office scene.
- Reuse `assets/images/tiles/floor/` and `assets/images/tiles/walls/`.
- Use a 64px scene grid for new objects and map placement.
- Include one four-direction player, desks, chairs, computers, plants, sofa, and coffee machine.
- Keep login, Supabase, multiplayer, chat, interaction UI, AI NPCs, and AI integrations out of this phase.

---

### Task 1: Create the Flutter Web shell

**Files:**
- Create: `pubspec.yaml`
- Create: `lib/main.dart`
- Create: `web/index.html`
- Create: `test/widget_test.dart`

**Interfaces:**
- Produces: `OfficeApp`, a `MaterialApp` hosting `OfficeScreen`.

- [ ] **Step 1: Write the failing widget test**

```dart
testWidgets('shows the virtual office title', (tester) async {
  await tester.pumpWidget(const OfficeApp());
  expect(find.text('AI Office'), findsOneWidget);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/widget_test.dart`

Expected: FAIL because `OfficeApp` does not exist.

- [ ] **Step 3: Create the minimal shell**

```dart
class OfficeApp extends StatelessWidget {
  const OfficeApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(body: Center(child: Text('AI Office'))),
  );
}
```

Add `flame: ^1.20.0` under dependencies and asset directory entries for `assets/images/tiles/` in `pubspec.yaml`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/widget_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml lib/main.dart web/index.html test/widget_test.dart
git commit -m "feat: scaffold Flutter web office"
```

### Task 2: Create and register pixel assets

**Files:**
- Create: `assets/images/characters/office_worker.png`
- Create: `assets/images/objects/desk.png`
- Create: `assets/images/objects/chair.png`
- Create: `assets/images/objects/computer.png`
- Create: `assets/images/objects/plant.png`
- Create: `assets/images/objects/sofa.png`
- Create: `assets/images/objects/coffee_machine.png`
- Modify: `pubspec.yaml`

**Interfaces:**
- Consumes: asset-root declarations from Task 1.
- Produces: PNG asset paths used by `OfficeMap` and `OfficePlayer`.

- [ ] **Step 1: Write the failing asset-load test**

```dart
testWidgets('loads the player sprite asset', (tester) async {
  await tester.pumpWidget(const OfficeApp());
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/widget_test.dart`

Expected: FAIL because `office_worker.png` is absent from the asset bundle.

- [ ] **Step 3: Generate the assets and register their directories**

Generate transparent-background, top-down, soft 2D pixel-art PNGs. The player sheet must contain four 64×64 frames in this exact order: down, left, right, up. The six object PNGs must each fit inside a 64×64 frame. Add `assets/images/characters/` and `assets/images/objects/` as `pubspec.yaml` assets.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/widget_test.dart`

Expected: PASS with no asset-bundle exception.

- [ ] **Step 5: Commit**

```bash
git add assets/images pubspec.yaml test/widget_test.dart
git commit -m "feat: add office pixel assets"
```

### Task 3: Define map geometry and collisions

**Files:**
- Create: `lib/game/map/office_map.dart`
- Create: `lib/game/map/office_layout.dart`
- Create: `test/office_layout_test.dart`

**Interfaces:**
- Produces: `OfficeLayout.worldSize` (`Vector2(1280, 896)`) and `OfficeLayout.blockers` (`List<Rect>`).
- Consumed by: `OfficeGame` and `OfficePlayer`.

- [ ] **Step 1: Write the failing geometry test**

```dart
test('a desk rectangle blocks its centre point', () {
  expect(OfficeLayout.blockers.any((rect) => rect.contains(const Offset(416, 352))), isTrue);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/office_layout_test.dart`

Expected: FAIL because `OfficeLayout` does not exist.

- [ ] **Step 3: Implement the fixed office layout**

Create floor placements, perimeter walls, a meeting-room partition, three workstations, and a lounge. Define every wall and desk footprint as a `Rect` in `OfficeLayout.blockers`; draw only provided floor/wall assets and Task 2 object assets in `OfficeMap`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/office_layout_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/game/map test/office_layout_test.dart
git commit -m "feat: add office map and collision layout"
```

### Task 4: Add keyboard player movement and collision resolution

**Files:**
- Create: `lib/game/player/office_player.dart`
- Create: `test/office_player_test.dart`

**Interfaces:**
- Consumes: `OfficeLayout.blockers` and `OfficeLayout.worldSize`.
- Produces: `OfficePlayer.tryMove(Vector2 delta)` returning the resolved player position.

- [ ] **Step 1: Write the failing collision test**

```dart
test('stops before a blocking rectangle', () {
  final player = OfficePlayer.forTest(position: Vector2(350, 352));
  player.tryMove(Vector2(100, 0));
  expect(player.position.x, lessThan(400));
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/office_player_test.dart`

Expected: FAIL because `OfficePlayer` does not exist.

- [ ] **Step 3: Implement movement**

Use `KeyboardHandler` to map WASD and arrow keys to a normalized velocity. In `update(dt)`, attempt horizontal and vertical movement separately. Reject a proposed axis change when the 40×40 player hitbox overlaps a blocker or crosses the world boundary. Select the player-sheet frame by the latest non-zero direction.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/office_player_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/game/player test/office_player_test.dart
git commit -m "feat: add player movement and collisions"
```

### Task 5: Compose the Flame game and verify in Chrome

**Files:**
- Create: `lib/game/office_game.dart`
- Create: `lib/screens/office_screen.dart`
- Modify: `lib/main.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: `OfficeMap`, `OfficePlayer`, and `OfficeLayout.worldSize`.
- Produces: `OfficeGame` with `camera.follow(player)` and an `OfficeScreen` GameWidget.

- [ ] **Step 1: Write the failing integration widget test**

```dart
testWidgets('renders the office game screen', (tester) async {
  await tester.pumpWidget(const OfficeApp());
  expect(find.byType(GameWidget<OfficeGame>), findsOneWidget);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/widget_test.dart`

Expected: FAIL because `OfficeScreen` does not host a `GameWidget<OfficeGame>`.

- [ ] **Step 3: Compose the game**

In `OfficeGame.onLoad`, add `OfficeMap` and `OfficePlayer`, set the camera world bounds to `OfficeLayout.worldSize`, and call `camera.follow(player)`. Replace the shell body with `OfficeScreen`.

- [ ] **Step 4: Run automated verification**

Run: `flutter analyze && flutter test`

Expected: both commands exit with code 0.

- [ ] **Step 5: Run visual QA in Chrome**

Run: `flutter run -d chrome`

Press WASD and arrow keys; confirm the player moves, camera follows, and walls/desks stop movement. Capture a screenshot and inspect the image directly for empty assets, scale problems, and collision/layout problems.

- [ ] **Step 6: Commit**

```bash
git add lib test
git commit -m "feat: assemble interactive web office demo"
```

## Self-review

- Spec coverage: Tasks 1–5 cover Flutter Web, Flame, supplied tile reuse, generated assets, 64px placement, rooms, movement, camera, and collisions. Excluded systems are not added.
- Placeholder scan: no deferred implementation markers or undefined task references remain.
- Type consistency: `OfficeLayout.blockers`, `OfficeLayout.worldSize`, `OfficeMap`, `OfficePlayer`, `OfficeGame`, and `OfficeScreen` are introduced before use.
