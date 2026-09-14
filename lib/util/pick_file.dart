/// Opens the browser's native file picker and resolves with the chosen
/// file, or null if the user cancels (or `dart:html` isn't available —
/// notably `flutter test`'s VM). See pick_file_web.dart / pick_file_stub.dart.
export 'pick_file_types.dart';
export 'pick_file_stub.dart' if (dart.library.html) 'pick_file_web.dart';
