import 'package:yoyota_dealers/app/analysis_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yoyota_dealers/app/yoyota_dealers_app.dart';
import 'package:yoyota_dealers/application/analysis/analysis_controller.dart';
import 'package:yoyota_dealers/data/models/dealership_models.dart';
import 'package:yoyota_dealers/features/investigation/lead_evidence_dialog.dart';

import '../fixtures/analytics_fixture.dart';

void main() {
  for (final size in const [
    Size(1440, 1000),
    Size(1280, 800),
    Size(1024, 768),
    Size(768, 1024),
    Size(600, 900),
    Size(820, 1000),
    Size(390, 844),
  ]) {
    testWidgets('dashboard is responsive at ${size.width.toInt()}px',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      final controller = AnalysisController(dataset: _dashboardDataset());
      addTearDown(() {
        controller.dispose();
        tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(YoyotaDealersApp(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Sales performance'), findsOneWidget);
      expect(find.text('Target attainment'), findsOneWidget);
      expect(find.text('What needs attention'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('no-results state resets back to network view', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    final controller = AnalysisController(dataset: _dashboardDataset());
    addTearDown(() {
      controller.dispose();
      tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(YoyotaDealersApp(controller: controller));
    await tester.pumpAndSettle();
    controller.setSource('not-present');
    await tester.pumpAndSettle();
    expect(find.text('No records match these filters'), findsOneWidget);

    await tester.ensureVisible(find.text('Reset filters'));
    await tester.tap(find.text('Reset filters'));
    await tester.pumpAndSettle();

    expect(find.text('Target attainment'), findsOneWidget);
    expect(controller.filters.isDefault, isTrue);
  });

  testWidgets('branch row opens diagnostic route and rep drill-down',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    final controller = AnalysisController(dataset: _dashboardDataset());
    addTearDown(() {
      controller.dispose();
      tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(YoyotaDealersApp(controller: controller));
    await tester.pumpAndSettle();

    controller.setBranch('B1');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review branch & representatives'));
    await tester.pumpAndSettle();

    expect(find.text('Why this branch is performing this way'), findsOneWidget);
    expect(find.text('Network benchmark'), findsWidgets);

    await tester.ensureVisible(find.text('Rep One'));
    await tester.tap(find.text('Rep One'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Coaching and follow-up'), findsOneWidget);
    expect(find.text('Branch benchmark'), findsWidgets);
    expect(controller.filters.repId, 'R1');
  });

  testWidgets('evidence list opens the exact lead and explains inclusion',
      (tester) async {
    final controller = AnalysisController(dataset: _dashboardDataset());
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        return FilledButton(
          onPressed: () => showEvidenceListDialog(
            context: context,
            controller: controller,
            title: 'Exact evidence',
            subtitle: '1 exact supporting record',
            leadIds: const ['active-b1'],
            footer: 'Review follow-up.',
            inclusionReason: 'this opportunity has had no recent activity',
          ),
          child: const Text('Open evidence'),
        );
      }),
    ));
    await tester.tap(find.text('Open evidence'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('evidence-lead-active-b1')), findsOneWidget);
    expect(find.byKey(const Key('evidence-lead-delivered-b1')), findsNothing);

    await tester.tap(find.byKey(const Key('evidence-lead-active-b1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Included because this opportunity'),
        findsOneWidget);
    expect(find.text('Complete status timeline'), findsOneWidget);
    expect(find.text('Negotiation'), findsWidgets);
  });

  testWidgets('pipeline route recalculates when the analysis scope changes',
      (tester) async {
    final controller = AnalysisController(dataset: _dashboardDataset());
    addTearDown(controller.dispose);
    await tester.pumpWidget(YoyotaDealersApp(controller: controller));
    await tester.pumpAndSettle();

    AppNavigation.go(
        tester.element(find.text('Sales performance')), '/pipeline');
    await tester.pumpAndSettle();
    expect(find.text('Active opportunities'), findsOneWidget);
    expect(find.text('Pipeline by stage'), findsOneWidget);

    controller.setBranch('B2');
    await tester.pumpAndSettle();
    expect(find.text('No records match these filters.'), findsWidgets);
  });

  testWidgets('delivery route exposes comparisons and evidence',
      (tester) async {
    final controller = AnalysisController(dataset: _dashboardDataset());
    addTearDown(controller.dispose);
    await tester.pumpWidget(YoyotaDealersApp(controller: controller));
    await tester.pumpAndSettle();

    AppNavigation.go(
        tester.element(find.text('Sales performance')), '/delivery');
    await tester.pumpAndSettle();
    expect(find.text('Delivery performance'), findsOneWidget);
    expect(find.text('Delivery-duration distribution'), findsOneWidget);

    await tester.ensureVisible(find.text('Median').first);
    await tester.tap(find.text('Median').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('evidence-lead-delivered-b1')), findsOneWidget);
  });
}

DealershipDataset _dashboardDataset() => dataset(
      leads: [
        lead(
          id: 'delivered-b1',
          status: LeadStatus.delivered,
          journey: deliveredJourney(),
          branchId: 'B1',
          repId: 'R1',
          source: 'website',
          model: 'Model A',
          value: 1000,
        ),
        lead(
          id: 'active-b1',
          status: LeadStatus.negotiation,
          journey: [
            history(LeadStatus.newLead, day(1)),
            history(LeadStatus.contacted, day(2)),
            history(LeadStatus.testDrive, day(3)),
            history(LeadStatus.negotiation, day(5)),
          ],
          branchId: 'B1',
          repId: 'R1',
          source: 'walk_in',
          model: 'Model B',
          value: 800,
        ),
        lead(
          id: 'lost-b2',
          status: LeadStatus.lost,
          journey: [
            history(LeadStatus.newLead, day(1)),
            history(LeadStatus.contacted, day(2)),
            history(LeadStatus.lost, day(4)),
          ],
          branchId: 'B2',
          repId: 'R2',
          source: 'website',
          model: 'Model A',
          value: 500,
          lostReason: 'Fixture reason',
        ),
      ],
      deliveries: [
        Delivery(
          leadId: 'delivered-b1',
          orderDate: day(5),
          deliveryDate: day(7),
          daysToDeliver: 2,
          delayReason: null,
        ),
      ],
    );
