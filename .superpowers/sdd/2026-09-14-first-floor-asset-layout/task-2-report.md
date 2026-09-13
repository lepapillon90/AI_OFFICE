# Task 2 report: first-floor asset sheet split and registration

## TDD record

1. RED: Added `test/first_floor_asset_manifest_test.dart` before the manifest
   existed. Ran `flutter test test/first_floor_asset_manifest_test.dart`.
   The expected failure was an unresolved import for
   `package:ai_office/game/isometric/first_floor_asset_manifest.dart`, because
   the manifest had not yet been created. The sandboxed Flutter batch runner
   did not return its compiler diagnostic before timing out, so the expected
   failure was recorded from the missing production file rather than a captured
   test assertion.
2. GREEN: Created the manifest, generated the 23 sprite PNGs, and registered
   the six v4 directories in `pubspec.yaml`.
3. Verification: Ran
   `C:\Users\suhye\dev\flutter\bin\cache\dart-sdk\bin\dart.exe C:\Users\suhye\dev\flutter\packages\flutter_tools\bin\flutter_tools.dart test test\first_floor_asset_manifest_test.dart --no-pub --reporter expanded`.
   Result: `00:00 +1: All tests passed!`

## Output paths

- `assets/images/office_1f/v4/structure/`
- `assets/images/office_1f/v4/lobby/`
- `assets/images/office_1f/v4/cafe/`
- `assets/images/office_1f/v4/store/`
- `assets/images/office_1f/v4/branding/`
- `assets/images/office_1f/v4/entrance/`
- `lib/game/isometric/first_floor_asset_manifest.dart`

The source sheets under `assets/1층` were only read. The generated output has
23 non-empty PNGs, matching the 23 manifest entries. I inspected a generated
contact sheet and corrected crop bounds that included source-sheet labels.

## Commit

`feat: add first-floor v4 asset manifest` (committed with this report; the
final hash is included in the task handoff).

## Concerns

The v4 sprites are registered and ready for use, but no first-floor scene or
placement code was changed by scope; a subsequent task must choose scale,
anchor, and placement for these sprites.

## Fix round 1: source-label crop cleanup

### Root cause and correction

The confirmed fragments were detached remnants of the category labels in the
original source sheets. The elevator crop included the lower edge of the
elevator label, the counter crop included the lower edge of its category label,
and the entrance planter crop included both its category label and the label
below the pot.

The three PNGs were regenerated non-destructively from the original sheets
with tighter bounds. The elevator's intended call indicator and the counter's
plant top were composited back from their adjacent source pixels, so the
cleanup does not discard intended artwork. The planter is limited to its plant
and pot. Manifest paths, source sheets, dimensions used by layout code, and
all scene code remain unchanged.

### Visual and test verification

- Directly inspected the three corrected PNGs at native resolution.
- Regenerated the Task 3 renderer-level composition at
  `build/first_floor_cleanup_composition.png` using
  `FIRST_FLOOR_PREVIEW`; it shows the repaired elevators, cafe counter, and
  planter instances without the reported label fragments.
- Ran
  `flutter_tools.dart test test/iso_lobby_scene_test.dart test/first_floor_asset_manifest_test.dart --no-pub --reporter expanded`.
  Result: `00:00 +5: All tests passed!`

### Commit

`fix: remove first-floor v4 crop artifacts` (final hash is included in the
task handoff).
