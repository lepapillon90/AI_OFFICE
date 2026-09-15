import 'dart:async';

import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in the OS's default browser (via package:url_launcher).
/// Fire-and-forget, matching the sync `void` signature callers rely on —
/// failures (malformed URL, no handler registered) are swallowed rather
/// than surfaced, since there's nothing more specific a caller could do
/// with them.
void openInNewTab(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return;
  }
  unawaited(
    launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false),
  );
}
