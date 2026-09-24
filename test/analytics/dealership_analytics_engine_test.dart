import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yoyota_dealers/analytics/models/analytical_lead.dart';
import 'package:yoyota_dealers/analytics/models/analytics_results.dart';
import 'package:yoyota_dealers/analytics/services/dealership_analytics_engine.dart';
import 'package:yoyota_dealers/analytics/services/lead_feature_engineer.dart';
import 'package:yoyota_dealers/data/models/dealership_models.dart';
import 'package:yoyota_dealers/data/parsing/dealership_dataset_parser.dart';

import '../fixtures/analytics_fixture.dart';

void main() {
  late DealershipAnalyticsEngine engine;

  setUp(() {
    final leads = [
      lead(
        id: 'delivered',
        status: LeadStatus.delivered,
        journey: deliveredJourney(),
        value: 100,
      ),
      lead(
        id: 'lost-new',
        status: LeadStatus.lost,
        journey: [
          history(LeadStatus.newLead, day(1)),
          history(LeadStatus.lost, day(2)),
        ],
        value: 50,
        lostReason: 'No response',
      ),
      lead(
        id: 'lost-contacted',
        status: LeadStatus.lost,
        journey: [
          history(LeadStatus.newLead, day(1)),
          history(LeadStatus.contacted, day(2)),
          history(LeadStatus.lost, day(4)),
        ],
        branchId: 'B2',
        repId: 'R2',
        source: 'referral',
        model: 'Model B',
        value: 70,
        lostReason: 'Budget',
      ),
      lead(
        id: 'active-negotiation',
        status: LeadStatus.negotiation,
        journey: [
          history(LeadStatus.newLead, day(1)),
          history(LeadStatus.contacted, day(2)),
          history(LeadStatus.testDrive, day(3)),
          history(LeadStatus.negotiation, day(5)),
        ],
        value: 80,
        lastActivityAt: day(5),
      ),
      lead(
        id: 'active-order',
        status: LeadStatus.orderPlaced,
        journey: [
          history(LeadStatus.newLead, day(1)),
          history(LeadStatus.contacted, day(2)),
          history(LeadStatus.testDrive, day(3)),
          history(LeadStatus.negotiation, day(4)),
          history(LeadStatus.orderPlaced, day(5)),
        ],
        value: 90,
        expectedCloseDate: day(10),
        lastActivityAt: day(5),
      ),
    ];
    final withDates = dataset(
      leads: leads,
      deliveries: [
        Delivery(
          leadId: 'delivered',
          orderDate: day(5),
          deliveryDate: day(7),
          daysToDeliver: 2,
          delayReason: null,
        ),
      ],
    );
    engine = DealershipAnalyticsEngine(
      const LeadFeatureEngineer().build(withDates, snapshotDate: day(31)),
      ageingConfig: const PipelineAgeingConfig(
        ageingAfterDays: 7,
        staleAfterDays: 14,
        severelyStaleAfterDays: 21,
      ),
    );
  });

  test('overview uses only resolved leads in conversion denominator', () {
    final result = engine.businessOverview();
    expect(result.totalLeads, 5);
    expect(result.activeLeads, 2);
    expect(result.resolvedLeads, 3);
    expect(result.delivered, 1);
    expect(result.lost, 2);
    expect(result.resolvedConversion, closeTo(1 / 3, 0.0001));
    expect(result.activeOpportunityValue, 170);
    expect(result.deliveredDealValue, 100);
    expect(result.dealValue.median, 80);
  });

  test('empty and single-record scopes return safe denominators', () {
    final empty = engine.businessOverview(const []);
    expect(empty.totalLeads, 0);
    expect(empty.resolvedConversion, isNull);
    expect(empty.dealValue.average, isNull);

    final single = engine.businessOverview([engine.dataset.leads.first]);
    expect(single.resolvedConversion, 1);
    expect(single.dealValue.median, 100);
  });

  test('full funnel calculates progression, leakage, and speed', () {
    final funnel = engine.funnel();
    final newStage =
        funnel.singleWhere((item) => item.stage == FunnelStage.newLead);
    final contacted =
        funnel.singleWhere((item) => item.stage == FunnelStage.contacted);
    expect(newStage.reachedCount, 5);
    expect(newStage.progressionCount, 4);
    expect(newStage.leakageCount, 1);
    expect(newStage.progressionRate, 0.8);
    expect(newStage.leakageValue, 50);
    expect(newStage.leakedLeadIds, ['lost-new']);
    expect(contacted.reachedCount, 4);
    expect(contacted.progressionCount, 3);
    expect(contacted.leakageCount, 1);
    expect(contacted.averageTransitionDuration, const Duration(days: 1));
  });

  test('management gates attribute loss before each gate and value', () {
    final gates = engine.managementGates();
    final contact = gates.first;
    final testDrive = gates[1];
    expect(contact.lostBeforeGateCount, 1);
    expect(contact.lostBeforeGateValue, 50);
    expect(testDrive.lostBeforeGateCount, 1);
    expect(testDrive.lostBeforeGateValue, 70);
    expect(testDrive.lostBeforeGateLeadIds, ['lost-contacted']);
  });

  test('branch and rep grouping retain context and zero-workload reps', () {
    final branches = engine.branches();
    final branchOne = branches.singleWhere((item) => item.branchId == 'B1');
    expect(branchOne.metrics.leadVolume, 4);
    expect(branchOne.workloadPerSalesOfficer, 4);
    expect(branchOne.deliveryPerformance.count, 1);
    expect(branchOne.staleOpportunityValue, 170);
    expect(branchOne.staleOpportunityShare, 1);

    final reps = engine.salesReps();
    final repTwo = reps.singleWhere((item) => item.repId == 'R2');
    final manager = reps.singleWhere((item) => item.repId == 'M1');
    expect(repTwo.branchId, 'B2');
    expect(repTwo.metrics.lost, 1);
    expect(manager.metrics.leadVolume, 0);
  });

  test('source metrics keep raw and resolved conversions distinct', () {
    final web = engine.sources().singleWhere((item) => item.source == 'web');
    expect(web.volume, 4);
    expect(web.rawDeliveredRate, 0.25);
    expect(web.resolvedConversion, 0.5);
    expect(web.contactRate, 0.75);
    expect(web.testDriveAmongContacted, 1);
  });

  test('vehicle metrics expose economic importance without profitability', () {
    final modelA =
        engine.vehicles().singleWhere((item) => item.model == 'Model A');
    expect(modelA.leadCount, 4);
    expect(modelA.deliveredCount, 1);
    expect(modelA.deliveredValueShare, 1);
    expect(modelA.economicImportanceIndex, 1.25);
    expect(modelA.lossReasons['No response'], 1);
  });

  test('lost reasons retain original reason and dimensions', () {
    final budget =
        engine.lostReasons().singleWhere((item) => item.reason == 'Budget');
    expect(budget.total.count, 1);
    expect(budget.total.affectedValue, 70);
    expect(budget.byStage[FunnelStage.contacted]!.count, 1);
    expect(budget.byBranch['B2']!.count, 1);
    expect(budget.bySource['referral']!.count, 1);
    expect(budget.byModel['Model B']!.count, 1);
    expect(budget.byRep['R2']!.count, 1);
  });

  test('pipeline ageing and overdue order stage are snapshot based', () {
    final pipeline = engine.pipeline();
    expect(pipeline, hasLength(2));
    expect(
      pipeline
          .every((item) => item.ageingBand == PipelineAgeingBand.severelyStale),
      isTrue,
    );
    final order = pipeline.singleWhere((item) => item.leadId == 'active-order');
    expect(order.isOverdueOrderStage, isTrue);
    expect(order.expectedCloseSlippage, const Duration(days: 21));
  });

  test('pipeline operations aggregate value and retain exact evidence IDs', () {
    final result = engine.pipelineOperations();
    expect(result.activeCount, 2);
    expect(result.activeValue, 170);
    expect(result.staleValue, 170);
    expect(result.orderStageBacklog.leadIds, ['active-order']);
    expect(result.overdueExpectedClose.leadIds.toSet(),
        {'active-negotiation', 'active-order'});
    expect(
      result.byInactivity[PipelineAgeingBand.severelyStale]!.leadIds.toSet(),
      {'active-negotiation', 'active-order'},
    );
    expect(result.byStage[FunnelStage.negotiation]!.value, 80);
    expect(result.oldest.map((item) => item.leadId).toSet(),
        {'active-negotiation', 'active-order'});
  });

  test('delivery metrics calculate durations and expected-close timeliness',
      () {
    final result = engine.deliveries();
    expect(result.overall.count, 1);
    expect(result.overall.averageDays, 2);
    expect(result.withoutRecordedDelay.medianDays, 2);
    expect(result.byBranch['B1']!.count, 1);
    expect(result.byVehicle['Model A']!.count, 1);
    expect(result.expectedCloseLinkedCount, 1);
    expect(result.deliveredByExpectedCloseCount, 1);
  });

  test('delivery delay categories compare with no-delay baseline', () {
    final delivered = [
      lead(
        id: 'base',
        status: LeadStatus.delivered,
        journey: deliveredJourney(),
      ),
      lead(
        id: 'delay',
        status: LeadStatus.delivered,
        journey: deliveredJourney(offset: 1),
      ),
    ];
    final source = dataset(leads: delivered, deliveries: [
      Delivery(
        leadId: 'base',
        orderDate: day(5),
        deliveryDate: day(7),
        daysToDeliver: 2,
        delayReason: null,
      ),
      Delivery(
        leadId: 'delay',
        orderDate: day(6),
        deliveryDate: day(11),
        daysToDeliver: 5,
        delayReason: 'Logistics',
      ),
    ]);
    final analytics = DealershipAnalyticsEngine(
      const LeadFeatureEngineer().build(source, snapshotDate: day(31)),
    ).deliveries();
    expect(analytics.overall.medianDays, 3.5);
    expect(analytics.delayReasons.single.incrementalAverageDays, 3);
  });

  test('cohorts expose mature versus immature state', () {
    final oldLead = lead(
      id: 'old',
      status: LeadStatus.delivered,
      journey: deliveredJourney(),
    );
    final recentLead = lead(
      id: 'recent',
      status: LeadStatus.newLead,
      journey: [history(LeadStatus.newLead, DateTime.utc(2025, 2, 25))],
      createdAt: DateTime.utc(2025, 2, 25),
      lastActivityAt: DateTime.utc(2025, 2, 25),
      expectedCloseDate: DateTime.utc(2025, 3, 20),
    );
    final cohortEngine = DealershipAnalyticsEngine(
      const LeadFeatureEngineer().build(
        dataset(leads: [oldLead, recentLead]),
        snapshotDate: DateTime.utc(2025, 3, 2),
      ),
    );
    final cohorts = cohortEngine.cohorts();
    expect(cohorts.first.isMature, isTrue);
    expect(cohorts.last.isMature, isFalse);
  });

  test('all analytics regenerate from the supplied canonical dataset',
      () async {
    final source =
        await File('assets/data/dealership_data.json').readAsString();
    final parsed = const DealershipDatasetParser().parse(source).dataset!;
    final analytical = const LeadFeatureEngineer().build(parsed);
    final suppliedEngine = DealershipAnalyticsEngine(analytical);

    expect(analytical.leads, hasLength(510));
    expect(analytical.context.maturityDuration, isNotNull);
    expect(suppliedEngine.businessOverview().totalLeads, 510);
    expect(suppliedEngine.funnel(), hasLength(6));
    expect(suppliedEngine.managementGates(), hasLength(3));
    expect(suppliedEngine.branches(), hasLength(5));
    expect(suppliedEngine.salesReps(), hasLength(30));
    expect(suppliedEngine.sources(), isNotEmpty);
    expect(suppliedEngine.vehicles(), isNotEmpty);
    expect(suppliedEngine.lostReasons(), isNotEmpty);
    expect(suppliedEngine.pipeline(), isNotEmpty);
    expect(suppliedEngine.deliveries().overall.count, 160);
    expect(suppliedEngine.cohorts(), isNotEmpty);
  });
}
