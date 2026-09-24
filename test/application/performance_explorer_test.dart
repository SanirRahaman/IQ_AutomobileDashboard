import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:yoyota_dealers/analytics/services/performance_explorer.dart';
import 'package:yoyota_dealers/application/analysis/analysis_controller.dart';
import 'package:yoyota_dealers/application/analysis/analysis_filters.dart';
import 'package:yoyota_dealers/application/analysis/evidence_order.dart';
import 'package:yoyota_dealers/application/export/follow_up_csv.dart';
import 'package:yoyota_dealers/data/models/dealership_models.dart';
import 'package:yoyota_dealers/data/parsing/dealership_dataset_parser.dart';
import 'package:yoyota_dealers/features/dashboard/dashboard_view_data.dart';
import '../fixtures/analytics_fixture.dart';

void main() {
  AnalysisController fixture() => AnalysisController(
          dataset: dataset(leads: [
        lead(
            id: 'won',
            status: LeadStatus.delivered,
            journey: deliveredJourney(),
            value: 400),
        lead(id: 'lost', status: LeadStatus.lost, value: 200, journey: [
          history(LeadStatus.newLead, day(1)),
          history(LeadStatus.lost, day(3))
        ]),
        lead(
            id: 'active',
            status: LeadStatus.negotiation,
            model: 'Model B',
            source: null,
            branchId: 'B2',
            repId: 'R2',
            value: 900,
            lastActivityAt: day(5),
            expectedCloseDate: day(10),
            journey: [
              history(LeadStatus.newLead, day(1)),
              history(LeadStatus.negotiation, day(5))
            ]),
        lead(
            id: 'recent',
            status: LeadStatus.newLead,
            model: 'Model B',
            value: 500,
            createdAt: DateTime.utc(2025, 4, 15),
            journey: [history(LeadStatus.newLead, DateTime.utc(2025, 4, 15))]),
      ], deliveries: [
        Delivery(
            leadId: 'won',
            orderDate: day(5),
            deliveryDate: day(7),
            daysToDeliver: 2,
            delayReason: null),
        Delivery(
            leadId: 'won',
            orderDate: day(5),
            deliveryDate: DateTime.utc(2025, 2, 7),
            daysToDeliver: 33,
            delayReason: 'Stock'),
      ]));

  test('comparisons preserve cohort conversion, delivery events and evidence',
      () {
    final controller = fixture();
    addTearDown(controller.dispose);
    final data = controller.explore(ComparisonDimension.model);
    final a = data.rows.firstWhere((r) => r.label == 'Model A');
    expect(a.value(ComparisonMetric.deliveries), 2);
    expect(a.value(ComparisonMetric.deliveredValue), 800);
    expect(a.value(ComparisonMetric.conversion), .5);
    expect(a.denominator(ComparisonMetric.conversion), 2);
    expect(a.evidence(ComparisonMetric.deliveries), ['won', 'won']);
    expect(a.evidence(ComparisonMetric.conversion), ['won', 'lost']);
    expect(data.total.value(ComparisonMetric.activeCount), 2);
    expect(data.total.value(ComparisonMetric.lostCount), 1);
    expect(data.total.value(ComparisonMetric.staleCount), 1);
    expect(data.total.value(ComparisonMetric.staleValue), 900);
    expect(
        data
            .ranked(ComparisonMetric.conversion, ascending: true)
            .last
            .value(ComparisonMetric.conversion),
        isNull);
    expect(data.ranked(ComparisonMetric.deliveries).first.label, 'Model A');
    expect(data.ranked(ComparisonMetric.activeValue).first.label, 'Model B');
    expect(data.rows.firstWhere((r) => r.label == 'Model B').mature, isFalse);
  });

  test('month series includes empty months and labels partial coverage', () {
    final controller = fixture();
    addTearDown(controller.dispose);
    final data = controller.explore(ComparisonDimension.model);
    expect(data.months.map((m) => m.month.month), [1, 2, 3, 4]);
    expect(data.months.map((m) => m.slice.value(ComparisonMetric.deliveries)),
        [1, 1, 0, 0]);
    expect(data.months[2].slice.value(ComparisonMetric.conversion), isNull);
    expect(data.months.last.partial, isTrue);
    expect(data.monthChange(1, ComparisonMetric.deliveries), 0);
    expect(data.monthChange(2, ComparisonMetric.deliveries), -1);
    expect(data.monthChange(3, ComparisonMetric.deliveries), isNull);
    expect(data.monthChange(1, ComparisonMetric.conversion), isNull);
  });

  test('date filters separate lead creation from deliveries, keep snapshot',
      () {
    final controller = fixture();
    addTearDown(controller.dispose);
    final snapshot = controller.results.performance.snapshot;
    controller.setDateRange(AnalysisDateRange(
        start: DateTime.utc(2025, 2), end: DateTime.utc(2025, 2, 28)));
    final data = controller.explore(ComparisonDimension.model);
    expect(data.total.overview.totalLeads, 0);
    expect(data.total.deliveries.length, 1);
    expect(data.total.deliveryValue, 400);
    expect(data.total.overview.resolvedConversion, isNull);
    expect(controller.results.performance.snapshot, snapshot);
    expect(data.months.single.partial, isFalse);
    expect(
        const DashboardPresenter()
            .present(controller)
            .branches
            .firstWhere((b) => b.id == 'B1')
            .deliveryHealth,
        '33.0 days median');
    controller.setDateRange(AnalysisDateRange(
        start: DateTime.utc(2025, 2, 2), end: DateTime.utc(2025, 2, 28)));
    expect(controller.explore(ComparisonDimension.model).months.single.partial,
        isTrue);
  });

  test('branch, rep, model and source filters constrain comparisons and lists',
      () {
    final controller = fixture();
    addTearDown(controller.dispose);
    controller.setBranch('B2');
    controller.setSalesRep('R2');
    controller.setVehicleModel('Model B');
    final data = controller.explore(ComparisonDimension.source);
    expect(data.rows.single.label, 'Unattributed');
    expect(data.rows.single.evidence(ComparisonMetric.activeCount), ['active']);
    controller.setSource('web');
    expect(controller.explore(ComparisonDimension.source).rows, isEmpty);
  });

  test(
      'record sorting retains duplicate delivery alignment and active-only rules',
      () {
    final controller = fixture();
    addTearDown(controller.dispose);
    final records = {
      for (final l in controller.results.leadScope.leads) l.id: l
    };
    const ids = ['won', 'lost', 'active', 'recent'];
    expect(
        orderedEvidence(
            ids: ids, records: records, order: EvidenceOrder.highestValue),
        [2, 3, 0, 1]);
    expect(
        orderedEvidence(
                ids: ids, records: records, order: EvidenceOrder.inactivity)
            .first,
        2);
    expect(
        orderedEvidence(
                ids: ids, records: records, order: EvidenceOrder.overdue)
            .first,
        2);
    expect(
        orderedEvidence(
            ids: ['won', 'won'],
            records: records,
            order: EvidenceOrder.longestDelivery,
            deliveries: controller.dataset.deliveries),
        [1, 0]);
    final csv = const FollowUpCsv().create(
        dataset: controller.dataset,
        scopedRecords: records.values,
        requestedIds: ['recent', 'active', 'lost', 'outside'],
        label: 'test',
        preserveOrder: true);
    expect(csv.count, 2);
    expect(csv.content.indexOf('Customer recent'),
        lessThan(csv.content.indexOf('Customer active')));
    expect(csv.content, isNot(contains('Customer lost')));
  });

  test(
      'supplied dataset comparison totals reconcile with existing headline analytics',
      () {
    final parsed = const DealershipDatasetParser()
        .parse(File('assets/data/dealership_data.json').readAsStringSync());
    final controller = AnalysisController(dataset: parsed.dataset!);
    addTearDown(controller.dispose);
    for (final dimension in ComparisonDimension.values) {
      final data = controller.explore(dimension);
      expect(data.total.value(ComparisonMetric.conversion),
          controller.results.overview.resolvedConversion);
      expect(
          data.rows.fold<num>(
              0, (n, r) => n + r.value(ComparisonMetric.deliveries)!),
          controller.results.performance.deliveredCount);
      expect(
          data.rows.fold<num>(
              0, (n, r) => n + r.value(ComparisonMetric.deliveredValue)!),
          controller.results.performance.deliveredValue);
      expect(
          data.months.fold<num>(
              0, (n, r) => n + r.slice.value(ComparisonMetric.deliveries)!),
          controller.results.performance.deliveredCount);
      expect(
          data.rows.fold<num>(
              0, (n, r) => n + r.value(ComparisonMetric.activeCount)!),
          controller.results.overview.activeLeads);
    }
  });
}
