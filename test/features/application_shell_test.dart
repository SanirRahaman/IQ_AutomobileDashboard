import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yoyota_dealers/app/app_theme.dart';
import 'package:yoyota_dealers/app/appearance_controller.dart';
import 'package:yoyota_dealers/app/yoyota_dealers_app.dart';
import 'package:yoyota_dealers/application/analysis/analysis_controller.dart';
import 'package:yoyota_dealers/data/models/dealership_models.dart';
import '../fixtures/analytics_fixture.dart';

void main() {
  test('saved appearance is validated and defaults to system', () {
    for (final mode in ThemeMode.values) {
      final controller = AppearanceController(initialPreference: mode.name);
      expect(controller.mode, mode);
      controller.dispose();
    }
    final controller = AppearanceController(initialPreference: 'invalid');
    expect(controller.mode, ThemeMode.system);
    controller.dispose();
  });

  test('semantic text colours remain readable in both themes', () {
    for (final dark in [false, true]) {
      final c = AppPalette(dark);
      for (final pair in [
        (c.ink, c.surface),
        (c.muted, c.surface),
        (c.brand, c.brandSoft),
        (c.info, c.infoSoft),
        (c.positive, c.positiveSoft),
        (c.warning, c.warningSoft)
      ]) {
        final a = pair.$1.computeLuminance(), b = pair.$2.computeLuminance();
        expect((math.max(a, b) + .05) / (math.min(a, b) + .05),
            greaterThanOrEqualTo(4.5));
      }
    }
  });

  for (final width in [1440.0, 820.0, 390.0]) {
    testWidgets('shell themes, navigation and evidence at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      final controller = AnalysisController(
          dataset: dataset(leads: [
        lead(
            id: 'active',
            status: LeadStatus.newLead,
            journey: [history(LeadStatus.newLead, day(1))])
      ]));
      addTearDown(() {
        controller.dispose();
        tester.binding.setSurfaceSize(null);
        tester.platformDispatcher.clearPlatformBrightnessTestValue();
      });
      await tester.pumpWidget(YoyotaDealersApp(controller: controller));
      await tester.pumpAndSettle();
      final appearance =
          AppearanceScope.of(tester.element(find.text('Sales performance')));
      expect(appearance.mode, ThemeMode.system);
      Future<void> choose(String name) async {
        await tester.tap(find.byKey(const Key('appearance-menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(name).last);
        await tester.pumpAndSettle();
      }

      await choose('Dark');
      expect(
          Theme.of(tester.element(find.text('Sales performance'))).brightness,
          Brightness.dark);
      expect(controller.results.overview.activeLeads, 1);
      if (width >= 1200) {
        await tester.tap(find.byTooltip('Collapse sidebar'));
        await tester.pumpAndSettle();
        expect(appearance.collapsed, isTrue);
        await tester.tap(find.byTooltip('Expand sidebar'));
        await tester.pumpAndSettle();
      }
      if (width < 760) {
        await tester.tap(find.byKey(const Key('open-navigation')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const Key('performance-nav-followUp')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Active opportunities').last);
      await tester.tap(find.text('Active opportunities').last);
      await tester.pumpAndSettle();
      expect(
          Theme.of(tester.element(find.byTooltip('Close evidence'))).brightness,
          Brightness.dark);
      expect(find.byKey(const Key('evidence-lead-active')), findsOneWidget);
      if (width < 760) {
        final export = tester.widget<IconButton>(
            find.byKey(const Key('export-follow-up')));
        final scheme = Theme.of(tester.element(
                find.byKey(const Key('export-follow-up'))))
            .colorScheme;
        expect(export.style?.foregroundColor?.resolve({}), scheme.onPrimary);
      }
      await tester.tap(find.byTooltip('Close evidence'));
      await tester.pumpAndSettle();
      await choose('Light');
      expect(appearance.mode, ThemeMode.light);
      expect(
          Theme.of(tester.element(find.text('Sales performance'))).brightness,
          Brightness.light);
      await choose('System');
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(
          Theme.of(tester.element(find.text('Sales performance'))).brightness,
          Brightness.dark);
      expect(tester.takeException(), isNull);
    });
  }
}
