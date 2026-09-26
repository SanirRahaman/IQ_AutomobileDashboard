import 'package:flutter/material.dart';
import '../platform/preferences.dart';

class AppearanceController extends ChangeNotifier {
  AppearanceController({String? initialPreference}) {
    final saved = initialPreference ?? readPreference('yoyota.appearance');
    mode = ThemeMode.values.where((m) => m.name == saved).firstOrNull ??
        ThemeMode.system;
  }
  late ThemeMode mode;
  bool collapsed = false;

  void setMode(ThemeMode value) {
    if (mode == value) return;
    mode = value;
    writePreference('yoyota.appearance', value.name);
    notifyListeners();
  }

  void toggleSidebar() {
    collapsed = !collapsed;
    notifyListeners();
  }
}

class AppearanceScope extends InheritedNotifier<AppearanceController> {
  const AppearanceScope(
      {super.key,
      required AppearanceController controller,
      required super.child})
      : super(notifier: controller);

  static AppearanceController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppearanceScope>()!.notifier!;
}
