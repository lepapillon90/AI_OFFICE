import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'pick_file_types.dart';

/// A soft cap, not a server-enforced limit — just a UX guard against
/// accidentally trying to inline a huge file into memory as bytes before
/// upload. `docs/PHASE8_FILE_SHARING.md` covers the real limits.
const _maxBytes = 20 * 1024 * 1024;

/// Opens the browser's native file picker via a hidden `<input type=file>`
/// and resolves once the user picks a file (or null if they cancel — best
/// effort, since browsers don't reliably fire a "cancelled" event).
Future<PickedFile?> pickFile() async {
  final input = html.FileUploadInputElement();
  final completer = Completer<PickedFile?>();

  input.onChange.listen((_) async {
    final file = input.files?.firstOrNull;
    if (file == null) {
      completer.complete(null);
      return;
    }
    if (file.size > _maxBytes) {
      completer.complete(null);
      return;
    }
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;
    completer.complete(
      PickedFile(
        name: file.name,
        bytes: (reader.result as ByteBuffer).asUint8List(),
      ),
    );
  });

  // A cancelled picker fires neither `change` nor `focus` reliably across
  // browsers, so this is the best available signal: if the window regains
  // focus and no file arrived shortly after, assume cancellation.
  html.window.onFocus.first.then((_) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  });

  input.click();
  return completer.future;
}
