import 'dart:html' as html;
import 'dart:typed_data';

String createBlobUrl(Uint8List bytes, String mimeType) {
  final blob = html.Blob([bytes], mimeType);
  return html.Url.createObjectUrlFromBlob(blob);
}

void openHtmlWindow(String htmlContent) {
  final blob = html.Blob([htmlContent], 'text/html;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
}

String getUrlHash() {
  try {
    final h = html.window.location.hash;
    if (h.startsWith('#')) {
      return h.substring(1);
    }
    return h;
  } catch (_) {
    return '';
  }
}

void setUrlHash(String hash) {
  try {
    final current = getUrlHash();
    if (current != hash) {
      html.window.location.hash = hash.isEmpty ? '' : '#$hash';
    }
  } catch (_) {}
}

void listenToPopState(void Function() onPopState) {
  try {
    html.window.onPopState.listen((_) => onPopState());
    html.window.onHashChange.listen((_) => onPopState());
  } catch (_) {}
}
