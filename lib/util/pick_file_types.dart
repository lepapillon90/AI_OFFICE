import 'dart:typed_data';

/// One file picked from the OS's native file dialog. See pick_file.dart.
class PickedFile {
  const PickedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}
