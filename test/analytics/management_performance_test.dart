import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:yoyota_dealers/analytics/services/lead_feature_engineer.dart';
import 'package:yoyota_dealers/analytics/services/management_performance.dart';
import 'package:yoyota_dealers/application/analysis/analysis_controller.dart';
import 'package:yoyota_dealers/data/models/dealership_models.dart';
import 'package:yoyota_dealers/data/parsing/dealership_dataset_parser.dart';
import '../fixtures/analytics_fixture.dart';

void main() {
  final fixture = dataset(leads: [
    lead(
        id: 'delivered',
        status: LeadStatus.delivered,
        journey: deliveredJourney()),
    lead(
        id: 'active',
        status: LeadStatus.newLead,
        journey: [history(LeadStatus.newLead, day(1))])
  ], deliveries: [
    Delivery(
        leadId: 'delivered',
        orderDate: day(5),
        deliveryDate: day(7),
        daysToDeliver: 2,
        delayReason: null)
  ]);
  DealershipDataset withTargets(List<Target> targets) => DealershipDataset(
      metadata: fixture.metadata,
      branches: fixture.branches,
      salesReps: fixture.salesReps,
      leads: fixture.leads,
      deliveries: fixture.deliveries,
      targets: targets);
  final target =
      Target(branchId: 'B1', month: day(1), targetUnits: 4, targetRevenue: 100);
  ManagementPerformance run(List<Target> targets,
          {DateTime? start, DateTime? end, String? rep}) =>
      const ManagementPerformanceService().calculate(
          const LeadFeatureEngineer()
              .build(withTargets(targets), snapshotDate: day(31)),
          start: start,
          end: end,
          repId: rep);

  test(
      'matches delivery dates to branch-month targets; excludes missing branch targets',
      () {
    final r = run([target]);
    expect(r.total!.actual, 1);
    expect(r.total!.target, 4);
    expect(r.total!.attainment, .25);
    expect(r.total!.variance, -3);
    expect(r.total!.missingMonths, 1);
    expect(r.branches.last.target, isNull);
  });
  test('partial months retain full target and explicit qualification', () {
    final r = run([target], start: day(1), end: day(10));
    expect(r.total!.target, 4);
    expect(r.total!.partialPeriod, isTrue);
    expect(r.total!.status, contains('Partial period'));
    expect(r.comparison, isNull);
  });
  test(
      'no invented rep targets, no percentage for zero targets, duplicates excluded',
      () {
    expect(run([target], rep: 'R1').total, isNull);
    expect(run([target], rep: 'R1').unavailableReason,
        contains('branch and month'));
    expect(
        run([
          Target(
              branchId: 'B1', month: day(1), targetUnits: 0, targetRevenue: 0)
        ]).total!.attainment,
        isNull);
    expect(run([target, target]).total, isNull);
    expect(run([]).total, isNull);
  });
  test('delivery outside target month is excluded from matched numerator', () {
    final r = run([
      Target(
          branchId: 'B1',
          month: DateTime.utc(2025, 2),
          targetUnits: 9,
          targetRevenue: 100)
    ], start: DateTime.utc(2025, 2), end: DateTime.utc(2025, 2, 28));
    expect(r.total!.actual, 0);
    expect(r.total!.target, 9);
  });
  test(
      'supplied dataset regression: snapshot, outcomes, targets, warnings, maturity',
      () {
    final loaded = const DealershipDatasetParser()
        .parse(File('assets/data/dealership_data.json').readAsStringSync());
    final c = AnalysisController(
        dataset: loaded.dataset!, validationReport: loaded.report);
    addTearDown(c.dispose);
    expect(c.results.overview.delivered, 160);
    expect(c.results.overview.lost, 288);
    expect(c.results.overview.activeLeads, 62);
    expect(c.results.overview.resolvedConversion, closeTo(160 / 448, 1e-12));
    expect(c.results.performance.snapshot, DateTime.utc(2025, 12, 31));
    expect(c.results.performance.total!.actual, 160);
    expect(c.results.performance.total!.target, 1426);
    expect(loaded.report.warnings.length, 14);
    expect(c.results.cohorts.last.isMature, isFalse);
  });
  test(
      'complete months compare delivery events; partial and uncovered months do not',
      () {
    final loaded = const DealershipDatasetParser()
        .parse(File('assets/data/dealership_data.json').readAsStringSync())
        .dataset!;
    final data = const LeadFeatureEngineer().build(loaded);
    const service = ManagementPerformanceService();
    final dec = service.calculate(data,
        start: DateTime.utc(2025, 12), end: DateTime.utc(2025, 12, 31));
    expect(dec.comparison!.current, 52);
    expect(dec.comparison!.previous, 30);
    expect(
        service
            .calculate(data,
                start: DateTime.utc(2025, 12), end: DateTime.utc(2025, 12, 15))
            .comparison,
        isNull);
    expect(
        service
            .calculate(data,
                start: DateTime.utc(2025, 6), end: DateTime.utc(2025, 6, 30))
            .comparison,
        isNull);
  });
}
