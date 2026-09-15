import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

import 'pick_file_types.dart';

/// A soft cap, not a server-enforced limit — just a UX guard against
/// accidentally trying to inline a huge file into memory as bytes before
/// upload. `docs/PHASE8_FILE_SHARING.md` covers the real limits.
const _maxBytes = 20 * 1024 * 1024;

/// Opens the OS's native file picker (via package:file_selector) and
/// resolves with the chosen file, or null if the user cancels, picks
/// something over [_maxBytes], or the native dialog doesn't respond
/// within [_dialogTimeout].
///
/// package:file_picker was tried first, but its Windows backend
/// (windows_file_picker) spawns the native dialog on a separate isolate
/// with no error port wired up — a failure there (observed live: the
/// picker silently did nothing, no dialog, no exception, no console
/// output at all) leaves the caller awaiting a message that never
/// arrives, forever. file_selector is the more established, Google-
/// maintained package for this — but the same class of failure (a
/// native dialog call that just never returns, with nothing printed)
/// was also seen intermittently here after a couple of successful
/// picks in the same running app, cause not yet identified. The
/// debugPrints and timeout below exist to turn the next occurrence into
/// a diagnosable console line instead of another silent dead end.
const _dialogTimeout = Duration(seconds: 20);

Future<PickedFile?> pickFile() async {
  debugPrint('pickFile: opening native dialog…');
  final XFile? file;
  try {
    file = await openFile().timeout(_dialogTimeout);
  } on TimeoutException {
    debugPrint(
      'pickFile: native dialog did not respond within $_dialogTimeout — '
      'giving up. If no OS file dialog was ever visible on screen, this '
      'is the file_selector_windows plugin hanging, not a slow user.',
    );
    return null;
  } catch (e, st) {
    debugPrint('pickFile: openFile() threw: $e\n$st');
    return null;
  }
  if (file == null) {
    debugPrint('pickFile: cancelled (no file chosen)');
    return null;
  }
  final bytes = await file.readAsBytes();
  if (bytes.length > _maxBytes) {
    debugPrint(
      'pickFile: ${file.name} is ${bytes.length} bytes, over the '
      '$_maxBytes cap — dropped',
    );
    return null;
  }
  debugPrint('pickFile: picked ${file.name} (${bytes.length} bytes)');
  return PickedFile(name: file.name, bytes: bytes);
}
