import 'pick_file_types.dart';

/// Fallback used wherever `dart:html` isn't available — notably
/// `flutter test`'s VM. Always resolves to null, mirroring "user cancelled"
/// rather than throwing, since nothing in a test exercises a real picker.
Future<PickedFile?> pickFile() async => null;
