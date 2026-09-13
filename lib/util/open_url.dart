/// Opens a URL in a new browser tab on Flutter Web; a no-op anywhere
/// `dart:html` isn't available (notably `flutter test`'s VM). See
/// open_url_web.dart / open_url_stub.dart.
export 'open_url_stub.dart' if (dart.library.html) 'open_url_web.dart';
