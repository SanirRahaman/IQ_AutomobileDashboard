// Web-only implementation selected by conditional import. No domain code imports dart:html.
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void downloadCsv(String filename, String content) {
  final blob = html.Blob([content], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)..download = filename;
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  Future<void>.delayed(
      const Duration(seconds: 1), () => html.Url.revokeObjectUrl(url));
}
