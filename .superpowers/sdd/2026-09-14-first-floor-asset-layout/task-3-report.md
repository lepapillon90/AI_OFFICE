# Task 3 report: first-floor asset composition

## Status and implementation

Implemented the six reference-image zones using 42 visual placements and 22
unique paths from `FirstFloorAssetManifest`. The existing 28x18, 64px tile
foundation and 1792x1152 world remain unchanged. New objects are v4 manifest
assets; the existing floor renderer continues to use its unchanged v3 tiles.

Created `first_floor_asset_layout.dart` and `first_floor_asset_component.dart`,
connected the object component immediately after the floor component in
`IsoLobbyScene`, and added layout/scene/rendering coverage. No new collisions,
NPCs, interactions, login/chat/AI employee behavior, or other-floor changes.
Unrelated dirty work was preserved and excluded from the implementation commit.

Implementation commit: `d6fdf4d` — `feat: compose first-floor asset zones`.

## TDD evidence

All test commands used the direct Dart Flutter runner:

```powershell
& 'C:\Users\suhye\dev\flutter\bin\cache\dart-sdk\bin\dart.exe' `
  'C:\Users\suhye\dev\flutter\packages\flutter_tools\bin\flutter_tools.dart' `
  test <test paths> --no-pub --reporter expanded
```

The ordinary sandbox run could not access Flutter's SDK lock file. An approved
elevated invocation ran the same tests; this did not require application changes.

1. Added the intended six-zone test before its production file. First run
   demonstrated the missing-file compiler error. Then added only the empty data
   model scaffold and reran to obtain a real assertion failure:
   `Expected: contains all of [topLobby, cafe, centralPlaza, store, lounge,
   entranceLandscape]; Actual: Set:[]; has too few elements (0 < 6)`.
2. Changed the scene composition expectation before integrating objects:
   `Expected: length 2; Actual: [IsoFloorTilesComponent]; has length 1`.
   In that run the existing floor load test passed (`+1 -2`).
3. Added world/manifest and central-circulation checks against the empty layout.
   All three layout tests failed: empty zones, empty placements, and missing
   central-planter path (`+0 -3`). Then populated the layout.
4. With a load-free object component, the object loading test failed with
   `Expected: 22; Actual: 0`, while the other five tests passed (`+5 -1`).
   Then implemented unique-path loading.
5. Added the independent two-sprite pixel comparison and ran with an empty
   render method. It failed with `Expected: true; Actual: false; Rendered pixels
   must respect size, anchor and render layer`. Restored the rendering loop and
   verified GREEN. The fixture intentionally supplies a higher-layer sprite
   first and with a smaller foot Y, so input order and depth alone are wrong.

One intermediate test invocation had misplaced import directives; those were
corrected before collecting the actual assertion-based loading/rendering RED
results above. Compiler errors alone were not treated as sufficient RED evidence.

## Final verification

Ran these four test files together after the final production/test changes:

```text
test/first_floor_asset_layout_test.dart
test/iso_lobby_scene_test.dart
test/iso_lobby_layout_test.dart
test/first_floor_asset_manifest_test.dart
```

Result: `00:00 +13: All tests passed!`, exit code 0.

Ran `dart analyze` on the five scoped Dart files: `No issues found!`, exit code 0.
Ran `git diff --check` for those files: no whitespace errors. Git only reported
the repository's normal LF-to-CRLF conversion notices.

A broader run also included `test/lobby_runtime_test.dart` and
`test/floor_change_test.dart`. It reached `+17`, then remained without progress
for several minutes on `remote depth follows creation, movement, and lobby
visibility`. It was interrupted. This is an unresolved verification limitation,
not a passing runtime regression result; a baseline comparison was not made.

## Dimensions, anchors, and layers

- Each placement records asset path, world position, per-sprite size, zone,
  render layer, and anchor. Rendered bounds account for that anchor.
- Artwork sizes preserve the exact source crop aspect ratio using its native
  dimensions. Production placements use bottom-center foot anchors.
- The central tree planter is 240px wide and approximately 241px high, centered
  at x=896 with foot Y=772. Its small office sign ends at Y=820.
- The combined central feature spans x=776..1016 and approximately y=531..820.
  Its 128px circulation ring spans x=648..1144 and approximately y=403..948.
  Tests reject every non-central sprite rectangle intersecting this ring.
- The top reception ends at Y=374, commercial artwork remains to either side
  of the central ring, and the glass entrance begins below Y=976.
- Pond art uses layer -1; fountains render over it. Other assets sort by layer,
  then foot Y and X. The batch priority is -50000, above the existing floor's
  -100000 and below existing actors. Actor/object occlusion is not added in
  this visual pass.
- The component loads one Sprite for each distinct path and reuses it across
  placements while retaining draw order instead of grouping renders by path.

## Visual inspection

Generated and directly inspected the full 1792x1152 composition using the
actual Flame floor and object renderers through `PictureRecorder`, not an
approximation of the placement data:

`.superpowers/sdd/2026-09-14-first-floor-asset-layout/task-3-composition.png`

To regenerate, set `FIRST_FLOOR_PREVIEW` to an absolute PNG output path when
running `test/iso_lobby_scene_test.dart`. It is optional and ordinary test runs
write no screenshot. The PNG is a local QA artifact, not committed source.

The top reception/elevators/stairs, left cafe, central tree/sign, right store,
right lower lounge, and bottom glass entrance/pond landscape are recognizable
in one composition. The central circulation remains open. Furniture grouping
is balanced without accidental overlaps; pond/fountain and tree/sign layering
are deliberate. This is a renderer-level full-world composition, not a running
browser screenshot or a claim that all camera/player behavior was validated.

## Concerns and follow-up

The following defects belong to previously supplied Task 2 PNG crops and were
confirmed visually. They were left untouched following the parent's scope
ruling; final visual acceptance needs a re-render after their cleanup:

- `assets/images/office_1f/v4/structure/elevator.png`: unrelated thin horizontal
  fragment along its top edge, visible above each elevator.
- `assets/images/office_1f/v4/cafe/counter.png`: unrelated horizontal fragment
  at the top left, visible above the counter.
- `assets/images/office_1f/v4/entrance/planter.png`: horizontal fragment above
  the plant and source-sheet label below its pot; repeated in entrance/lounge.

The pond's lower edge was initially suspected from the composition, but direct
inspection showed its own shadow/outline, so it is not recorded as a confirmed
crop defect.

The v4 manifest has no separate menu board, long communal table, welcome mat,
standalone slogan board, or cafe chairs. The composition uses the available
round tables, counter with integrated equipment/slogan, office signs with
integrated slogan, and glass doorway. It does not invent assets to fill those
gaps. Parent was notified of these limitations before completion.

Runtime floor-switch/presence verification remains incomplete as noted above.
Only the scoped 13-test result and analyzer result are claimed as passed.
