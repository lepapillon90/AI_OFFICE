import 'dart:typed_data';

/// One file picked from the OS's native file dialog. Platform-agnostic (no
/// `dart:html`), so both pick_file_web.dart and pick_file_stub.dart can
/// share this same type without either importing the other.
class PickedFile {
  const PickedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}
