import 'package:file_picker/file_picker.dart';

import 'pick_file_types.dart';

/// A soft cap, not a server-enforced limit — just a UX guard against
/// accidentally trying to inline a huge file into memory as bytes before
/// upload. `docs/PHASE8_FILE_SHARING.md` covers the real limits.
const _maxBytes = 20 * 1024 * 1024;

/// Opens the OS's native file picker (via package:file_picker) and
/// resolves with the chosen file, or null if the user cancels or picks
/// something over [_maxBytes].
Future<PickedFile?> pickFile() async {
  final file = await FilePicker.pickFile();
  if (file == null) {
    return null;
  }
  final size = file.lengthSync() ?? await file.length();
  if (size != null && size > _maxBytes) {
    return null;
  }
  final bytes = await file.readAsBytes();
  if (bytes.length > _maxBytes) {
    return null;
  }
  return PickedFile(name: file.name, bytes: bytes);
}
