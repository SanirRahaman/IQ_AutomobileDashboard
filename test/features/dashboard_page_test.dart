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
    Size(820, 1000),
    Size(390, 844)
  ]) {
    testWidgets(
        'KPI dialogs preserve evidence and remain responsive at ${size.width}',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      final controller = AnalysisController(dataset: _dashboardDataset());
      addTearDown(() {
        controller.dispose();
        tester.binding.setSurfaceSize(null);
      });
      await tester.pumpWidget(YoyotaDealersApp(controller: controller));
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(
          of: find.byKey(const Key('kpi-enquiries')),
          matching: find.byType(IconButton)));
      await tester.pumpAndSettle();
      expect(find.text('Leads created inside the selected period and filters.'),
          findsOneWidget);
      expect(find.byKey(const Key('export-records')), findsNothing);
      await tester.tap(find.byKey(const Key('metric-help-close')));
      await tester.pumpAndSettle();

      Future<void> open(String kind) async {
        final card = find.byKey(Key('kpi-$kind'));
        await tester.ensureVisible(card);
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      Future<void> close() async {
        await tester.tap(find.byTooltip('Close evidence'));
        await tester.pumpAndSettle();
      }

      await open('enquiries');
      expect(find.byKey(const Key('evidence-lead-active-b1')), findsOneWidget);
      await tester.scrollUntilVisible(
          find.byKey(const Key('evidence-lead-lost-b2')), 100,
          scrollable: find
              .descendant(
                  of: find.descendant(
                      of: find.byType(Dialog), matching: find.byType(ListView)),
                  matching: find.byType(Scrollable))
              .first);
      expect(find.byKey(const Key('evidence-lead-lost-b2')), findsOneWidget);
      await close();

      await open('conversion');
      expect(find.textContaining('50.0% = 1 delivered ÷ 2 resolved'),
          findsOneWidget);
      expect(find.byKey(const Key('evidence-lead-active-b1')), findsNothing);
      await tester.tap(find.text('Lost (1)'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('evidence-lead-delivered-b1')), findsNothing);
      await tester.tap(find.byKey(const Key('evidence-lead-lost-b2')));
      await tester.pumpAndSettle();
      expect(find.text('Complete status timeline'), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await close();

      await open('active');
      expect(find.byKey(const Key('evidence-lead-active-b1')), findsOneWidget);
      expect(find.byKey(const Key('evidence-lead-delivered-b1')), findsNothing);
      await close();

      await open('delivered');
      await tester.tap(find.byKey(const Key('evidence-delivery-0')));
      await tester.pumpAndSettle();
      expect(find.text('Delivery record'), findsOneWidget);
      expect(find.text('07 Jan 2025'), findsWidgets);
      expect(tester.takeException(), isNull);
      await close();

      await open('attention');
      expect(find.text('No supporting opportunities are available.'),
          findsOneWidget);
      await close();

      await open('target');
      expect(find.text('Target attainment breakdown'), findsOneWidget);
      expect(
          find.text(
              'No comparable branch targets are available for this period.'),
          findsWidgets);
      await tester.tap(find.byTooltip('Close target breakdown'));
      await tester.pumpAndSettle();

      controller.setBranch('B1');
      await tester.pumpAndSettle();
      await open('enquiries');
      expect(find.byKey(const Key('evidence-lead-lost-b2')), findsNothing);
      await close();
    });
  }

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

  testWidgets('target card shows supplied monthly actuals and exclusions',
      (tester) async {
    final base = _dashboardDataset();
    final controller = AnalysisController(
        dataset: DealershipDataset(
            metadata: base.metadata,
            branches: base.branches,
            salesReps: base.salesReps,
            leads: base.leads,
            deliveries: base.deliveries,
            targets: [
          Target(
              branchId: 'B1', month: day(1), targetUnits: 4, targetRevenue: 100)
        ]));
    addTearDown(controller.dispose);
    await tester.pumpWidget(YoyotaDealersApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kpi-target')));
    await tester.pumpAndSettle();
    expect(find.text('25.0% attained'), findsWidgets);
    expect(
        find.text('1 actual deliveries ÷ 4 target vehicles'), findsOneWidget);
    expect(find.text('Branch One · Jan 2025'), findsOneWidget);
    expect(find.text('Actual 1'), findsOneWidget);
    expect(find.text('Variance -3'), findsOneWidget);
    expect(find.text('Excluded · missing, duplicate or invalid target'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('management gates progressively reveal the full journey',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    final controller = AnalysisController(dataset: _dashboardDataset());
    addTearDown(() {
      controller.dispose();
      tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(YoyotaDealersApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Management gates').first);
    expect(find.text('Contact'), findsWidgets);
    expect(find.text('Test drive'), findsWidgets);
    expect(find.text('Close'), findsWidgets);

    await tester.tap(find.text('Full journey'));
    await tester.pumpAndSettle();
    expect(find.text('Full sales journey'), findsOneWidget);
    expect(find.textContaining('median to next stage'), findsWidgets);
    expect(find.textContaining('affected value'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

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
    expect(find.byType(Dialog), findsOneWidget);
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
