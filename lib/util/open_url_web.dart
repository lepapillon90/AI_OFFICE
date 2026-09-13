import 'dart:html' as html;

/// Opens [url] in a new browser tab.
void openInNewTab(String url) => html.window.open(url, '_blank');
