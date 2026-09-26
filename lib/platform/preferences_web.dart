// Browser storage may be unavailable in restricted contexts.
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

String? readPreference(String key) {
  try {
    return html.window.localStorage[key];
  } catch (_) {
    return null;
  }
}

void writePreference(String key, String value) {
  try {
    html.window.localStorage[key] = value;
  } catch (_) {
    // The in-session setting still works without persistence.
  }
}
