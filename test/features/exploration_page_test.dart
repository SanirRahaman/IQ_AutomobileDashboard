import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yoyota_dealers/app/yoyota_dealers_app.dart';
import 'package:yoyota_dealers/application/analysis/analysis_controller.dart';
import 'package:yoyota_dealers/data/models/dealership_models.dart';
import '../fixtures/analytics_fixture.dart';

void main() {
  for (final size in [
    const Size(1440, 1000),
    const Size(820, 1000),
    const Size(390, 844)
  ]) {
    testWidgets(
        'explorer comparisons, trend evidence and sort at ${size.width}',
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
          controller: controller, initialUri: Uri(path: '/explore')));
      await tester.pumpAndSettle();
      expect(find.text('Explore performance'), findsOneWidget);
      expect(tester.takeException(), isNull);
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await tap(find.text('Compare two'));
      expect(find.byKey(const Key('compare-a')), findsOneWidget);
      await tap(find.byKey(const Key('explore-metric')));
      await tap(find.text('Resolved conversion').last);
      expect(find.textContaining('1 resolved leads'), findsOneWidget);
      await tap(find.byKey(const Key('explore-tab-1')));
      await tap(find.text('View month records'));
      expect(find.byKey(const Key('evidence-delivery-0')), findsOneWidget);
      await tap(find.byKey(const Key('evidence-delivery-0')));
      expect(find.text('Complete status timeline'), findsOneWidget);
      await tap(find.byTooltip('Close evidence'));
      await tap(find.byKey(const Key('explore-tab-2')));
      await tap(find.text('Active opportunities').last);
      await tap(find.byKey(const Key('evidence-sort')));
      await tap(find.text('Highest value first').last);
      expect(find.byKey(const Key('evidence-lead-active')), findsOneWidget);
      expect(find.byKey(const Key('evidence-lead-sale')), findsNothing);
      await tap(find.byTooltip('Close evidence'));
      expect(tester.takeException(), isNull);
    });
  }
}
