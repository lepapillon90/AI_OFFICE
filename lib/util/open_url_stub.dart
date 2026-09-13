/// Fallback used wherever `dart:html` isn't available — notably
/// `flutter test`'s VM, which has no web platform at all. A no-op rather
/// than a throw, since this app only ever runs as Flutter Web in
/// production (see pubspec.yaml's description) and nothing in a test
/// exercises what opening a real tab would do.
void openInNewTab(String url) {}
