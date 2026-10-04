import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yoyota_dealers/app/yoyota_dealers_app.dart';
import 'package:yoyota_dealers/application/analysis/analysis_controller.dart';
import 'package:yoyota_dealers/data/models/dealership_models.dart';
import 'package:yoyota_dealers/analytics/services/performance_explorer.dart';
import 'package:yoyota_dealers/app/analysis_router.dart';
import 'package:yoyota_dealers/features/exploration/exploration_presenter.dart';
import '../fixtures/analytics_fixture.dart';

void main() {
  for (final size in [
    const Size(1440, 1000),
    const Size(820, 1000),
    const Size(390, 844)
  ]) {
    testWidgets(
        'dedicated comparisons, trend evidence and scope at ${size.width}',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      final controller = AnalysisController(
          dataset: dataset(leads: [
        lead(
            id: 'sale',
            status: LeadStatus.delivered,
            journey: deliveredJourney()),
        lead(
            id: 'active',
            status: LeadStatus.newLead,
            model: 'Model B',
            value: 900,
            journey: [history(LeadStatus.newLead, day(1))],
            lastActivityAt: day(31)),
      ], deliveries: [
        Delivery(
            leadId: 'sale',
            orderDate: day(5),
            deliveryDate: day(7),
            daysToDeliver: 2,
            delayReason: null)
      ]));
      addTearDown(() {
        controller.dispose();
        tester.binding.setSurfaceSize(null);
      });
      await tester.pumpWidget(YoyotaDealersApp(
          controller: controller, initialUri: Uri(path: '/compare/models')));
      await tester.pumpAndSettle();
      expect(find.text('Compare vehicle models'), findsOneWidget);
      for (final metric in comparisonMetricsFor(ComparisonDimension.model)) {
        expect(
            find.byKey(Key('explore-metric-${metric.name}')), findsOneWidget);
      }
      expect(find.text('2. Compare by'), findsNothing);
      await tester.ensureVisible(find.text('More measures'));
      await tester.tap(find.text('More measures'));
      await tester.pumpAndSettle();
      final extra = find.byKey(const Key('explore-metric-lostCount'));
      await tester.ensureVisible(extra);
      await tester.tap(extra);
      await tester.pumpAndSettle();
      expect(find.text('Lost opportunities by vehicle models'), findsOneWidget);
      await tester
          .ensureVisible(find.text('More measures · Lost opportunities'));
      await tester.tap(find.text('More measures · Lost opportunities'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ranking details & compare two'));
      await tester.tap(find.text('Ranking details & compare two'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Compare two'));
      await tester.tap(find.text('Compare two'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('compare-a')), findsOneWidget);
      expect(find.byKey(const Key('compare-b')), findsOneWidget);
      if (size.width < 760) {
        await tester.tap(find.byKey(const Key('open-navigation')));
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const Key('performance-nav-models')), findsOneWidget);
      expect(tester.takeException(), isNull);
      Future<void> tap(Finder finder) async {
        if (finder.evaluate().isEmpty &&
            find.byKey(const Key('open-navigation')).evaluate().isNotEmpty) {
          await tester.tap(find.byKey(const Key('open-navigation')));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await tap(find.byKey(const Key('performance-nav-branches')));
      expect(find.text('Resolved conversion by branches'), findsOneWidget);
      expect(
          find.byKey(const Key('explore-metric-conversion')), findsOneWidget);
      expect(find.text('Ranking details & compare two'), findsOneWidget);
      controller.setBranch('B1');
      await tester.pumpAndSettle();
      await tap(find.byKey(const Key('performance-nav-representatives')));
      expect(find.textContaining('Scope restriction:'), findsOneWidget);
      await tap(find.byKey(const Key('performance-nav-trends')));
      final router =
          Router.of(tester.element(find.text('Monthly performance trends')))
              .routerDelegate as AnalysisRouter;
      expect(router.currentConfiguration.path, '/explore/trends');
      expect(router.currentConfiguration.queryParameters['branch'], 'B1');
      await tap(find.text('View month records'));
      expect(find.byKey(const Key('evidence-delivery-0')), findsOneWidget);
      await tap(find.byKey(const Key('evidence-delivery-0')));
      expect(find.text('Complete status timeline'), findsOneWidget);
      await tap(find.byTooltip('Close evidence'));
      await tap(find.byKey(const Key('performance-nav-followUp')));
      await tap(find.text('Active opportunities').last);
      await tap(find.byKey(const Key('evidence-sort')));
      await tap(find.text('Highest value first').last);
      expect(find.byKey(const Key('evidence-lead-active')), findsOneWidget);
      expect(find.byKey(const Key('evidence-lead-sale')), findsNothing);
      await tap(find.byTooltip('Close evidence'));
      await tap(find.byKey(const Key('performance-nav-branches')));
      expect(
          tester
              .widget<ChoiceChip>(
                  find.byKey(const Key('explore-metric-conversion')))
              .selected,
          isTrue);
      expect(controller.filters.branchId, 'B1');
      await tap(find.byKey(const Key('performance-nav-overview')));
      expect(router.currentConfiguration.path, '/');
      expect(controller.filters.branchId, 'B1');
      expect(find.text('Business overview'), findsOneWidget);
      await tap(find.byKey(const Key('performance-nav-followUp')));
      expect(router.currentConfiguration.path, '/explore/follow-up');
      expect(find.text('Active opportunities'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
