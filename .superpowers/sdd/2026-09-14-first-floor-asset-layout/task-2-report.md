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
