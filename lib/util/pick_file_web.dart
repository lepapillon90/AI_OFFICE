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
  // Some browsers only reliably show the native dialog (and fire `change`)
  // for an input that's actually attached to the document — a detached
  // element's click() can silently no-op. Hidden via `display: none` so it
  // never affects layout; removed again once this resolves.
  final input = html.FileUploadInputElement()..style.display = 'none';
  html.document.body!.append(input);
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
    if (!completer.isCompleted) {
      // `FileReader.result` is typed `Object?` in dart:html — in practice
      // this DDC/dart2js binding hands back a `Uint8List` directly, not
      // the `ByteBuffer` the (older, browser-native) API implies, so a
      // bare `as ByteBuffer` cast throws. Accept either shape.
      final result = reader.result;
      final bytes =
          result is ByteBuffer ? result.asUint8List() : result as Uint8List;
      completer.complete(PickedFile(name: file.name, bytes: bytes));
    }
  });

  // A cancelled picker fires neither `change` nor a dedicated "cancelled"
  // event in any browser, so this infers it from focus: the OS dialog
  // steals window focus while open (`blur`), and cancelling — with no
  // `change` following — hands it back (`focus`). Gating on having seen a
  // `blur` first avoids misreading an unrelated focus event (e.g. one that
  // arrives before the dialog ever opens) as a cancellation.
  var dialogMayHaveOpened = false;
  final blurSub = html.window.onBlur.listen((_) => dialogMayHaveOpened = true);
  html.window.onFocus.listen((_) async {
    if (!dialogMayHaveOpened) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  });

  input.click();
  final result = await completer.future;
  await blurSub.cancel();
  input.remove();
  return result;
}
