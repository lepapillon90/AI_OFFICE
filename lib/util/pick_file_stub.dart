import 'pick_file_types.dart';

/// This app is desktop-only now — no native file picker is wired up yet,
/// so this always resolves to null, mirroring "user cancelled" rather than
/// throwing.
Future<PickedFile?> pickFile() async => null;
