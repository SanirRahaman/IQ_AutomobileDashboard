import 'package:flutter_test/flutter_test.dart';
import 'package:yoyota_dealers/application/analysis/analysis_controller.dart';
import 'package:yoyota_dealers/application/analysis/analysis_filters.dart';
import 'package:yoyota_dealers/data/models/dealership_models.dart';

import '../fixtures/analytics_fixture.dart';

void main() {
  late AnalysisController controller;

  setUp(() {
    controller = AnalysisController(dataset: _filterDataset());
  });

  tearDown(() => controller.dispose());

  test(
      'date scope uses creation date for leads and delivery date for deliveries',
      () {
    controller.setDateRange(AnalysisDateRange(
      start: DateTime.utc(2025, 2, 1),
      end: DateTime.utc(2025, 2, 28),
    ));

    expect(controller.results.overview.totalLeads, 2);
    expect(
      controller.results.leadScope.leads.map((lead) => lead.id).toSet(),
      {'L2', 'L3'},
    );
    expect(controller.results.deliveries.overall.count, 1);
    expect(
      controller.results.deliveryScope.leads.single.id,
      'L1',
      reason: 'L1 was created in January but delivered in February.',
    );
  });

  test('branch scope recalculates records and constrains available reps', () {
    controller.setBranch('B1');

    expect(controller.results.overview.totalLeads, 3);
    expect(
      controller.results.leadScope.leads.every((lead) => lead.branchId == 'B1'),
      isTrue,
    );
    expect(
      controller.availableSalesReps.map((rep) => rep.id).toSet(),
      {'R1', 'M1'},
    );
    expect(
        controller.results.branches.map((branch) => branch.branchId), ['B1']);
  });

  test('rep scope retains branch context and recalculates results', () {
    controller.setSalesRep('R2');

    expect(controller.filters.branchId, 'B2');
    expect(controller.filters.repId, 'R2');
    expect(controller.results.overview.totalLeads, 2);
    expect(
      controller.results.leadScope.leads.every((lead) => lead.repId == 'R2'),
      isTrue,
    );
    expect(controller.routeUri.path, '/rep/R2');
  });

  test('source scope recalculates KPI and grouped results', () {
    controller.setSource('web');

    expect(controller.results.overview.totalLeads, 3);
    expect(controller.results.sources, hasLength(1));
    expect(controller.results.sources.single.source, 'web');
  });

  test('vehicle scope recalculates KPI and vehicle results', () {
    controller.setVehicleModel('Model B');

    expect(controller.results.overview.totalLeads, 2);
    expect(controller.results.vehicles, hasLength(1));
    expect(controller.results.vehicles.single.model, 'Model B');
  });

  test('raw lead status scope supports canonical and future values', () {
    controller.setLeadStatus('contacted');

    expect(controller.results.overview.totalLeads, 1);
    expect(controller.results.leadScope.leads.single.id, 'L3');
  });

  test('combined filters intersect at the analytical source', () {
    controller.replaceFilters(AnalysisFilters(
      dateRange: AnalysisDateRange(
        start: DateTime.utc(2025, 2, 1),
        end: DateTime.utc(2025, 2, 28),
      ),
      branchId: 'B1',
      source: 'web',
      vehicleModel: 'Model A',
      leadStatus: 'contacted',
    ));

    expect(controller.results.overview.totalLeads, 1);
    expect(controller.results.leadScope.leads.single.id, 'L3');
    expect(controller.results.funnel.first.reachedCount, 1);
  });

  test('reset returns to default network scope', () {
    controller.setBranch('B1');
    controller.setSource('web');
    expect(controller.results.overview.totalLeads, lessThan(5));

    controller.reset();

    expect(controller.filters.isDefault, isTrue);
    expect(controller.results.overview.totalLeads, 5);
    expect(controller.routeUri.path, '/');
  });

  test('no-match scope produces empty typed analytics', () {
    controller.setSource('does-not-exist');

    expect(controller.results.overview.totalLeads, 0);
    expect(controller.results.overview.resolvedConversion, isNull);
    expect(controller.results.pipeline, isEmpty);
    expect(controller.results.insights, isEmpty);
    expect(
      controller.results.funnel.every((stage) => stage.reachedCount == 0),
      isTrue,
    );
  });

  test('changing branch clears an incompatible selected rep', () {
    controller.setSalesRep('R1');
    expect(controller.filters.repId, 'R1');

    controller.setBranch('B2');

    expect(controller.filters.branchId, 'B2');
    expect(controller.filters.repId, isNull);
    expect(controller.availableSalesReps.map((rep) => rep.id), ['R2']);
  });

  test('direct branch and rep routes restore analytical scope', () {
    controller.applyRoute(Uri.parse('/branch/B1?source=web'));
    expect(controller.filters.branchId, 'B1');
    expect(controller.filters.source, 'web');
    expect(controller.results.overview.totalLeads, 2);

    controller.applyRoute(
        Uri.parse('/rep/R2?from=2025-01-01&to=2025-01-31&model=Model%20B'));
    expect(controller.filters.repId, 'R2');
    expect(controller.filters.branchId, 'B2');
    expect(controller.filters.vehicleModel, 'Model B');
    expect(controller.results.overview.totalLeads, 1);
    expect(controller.routeUri.path, '/rep/R2');
  });

  test('filtering recalculates insights and their evidence', () {
    controller.dispose();
    controller = AnalysisController(dataset: _insightDataset());
    final networkInsight = controller.results.insights.singleWhere(
      (insight) => insight.id == 'branch.low_conversion.B1',
    );
    expect(networkInsight.affectedLeadCount, 20);
    expect(networkInsight.affectedLeadIds, hasLength(20));

    controller.setBranch('B1');

    expect(
      controller.results.insights.map((insight) => insight.id),
      isNot(contains('branch.low_conversion.B1')),
      reason: 'The branch becomes its own scoped network benchmark.',
    );
    for (final insight in controller.results.insights) {
      expect(insight.affectedLeadCount, insight.affectedLeadIds.length);
      expect(
        insight.affectedLeadIds.every((id) => id.startsWith('weak-')),
        isTrue,
      );
    }
  });
}

DealershipDataset _filterDataset() => dataset(
      leads: [
        _leadAt(
          id: 'L1',
          status: LeadStatus.delivered,
          created: DateTime.utc(2025, 1, 5),
          source: 'web',
          model: 'Model A',
          branchId: 'B1',
          repId: 'R1',
        ),
        _leadAt(
          id: 'L2',
          status: LeadStatus.lost,
          created: DateTime.utc(2025, 2, 5),
          source: 'referral',
          model: 'Model B',
          branchId: 'B1',
          repId: 'R1',
        ),
        _leadAt(
          id: 'L3',
          status: LeadStatus.contacted,
          created: DateTime.utc(2025, 2, 10),
          source: 'web',
          model: 'Model A',
          branchId: 'B1',
          repId: 'R1',
        ),
        _leadAt(
          id: 'L4',
          status: LeadStatus.delivered,
          created: DateTime.utc(2025, 1, 8),
          source: 'web',
          model: 'Model B',
          branchId: 'B2',
          repId: 'R2',
        ),
        _leadAt(
          id: 'L5',
          status: LeadStatus.newLead,
          created: DateTime.utc(2025, 3, 1),
          source: 'social',
          model: 'Model C',
          branchId: 'B2',
          repId: 'R2',
        ),
      ],
      deliveries: [
        Delivery(
          leadId: 'L1',
          orderDate: DateTime.utc(2025, 2, 1),
          deliveryDate: DateTime.utc(2025, 2, 5),
          daysToDeliver: 4,
          delayReason: null,
        ),
        Delivery(
          leadId: 'L4',
          orderDate: DateTime.utc(2025, 1, 10),
          deliveryDate: DateTime.utc(2025, 1, 15),
          daysToDeliver: 5,
          delayReason: null,
        ),
      ],
    );

Lead _leadAt({
  required String id,
  required LeadStatus status,
  required DateTime created,
  required String source,
  required String model,
  required String branchId,
  required String repId,
}) {
  final raw = switch (status) {
    LeadStatus.newLead => 'new',
    LeadStatus.contacted => 'contacted',
    LeadStatus.delivered => 'delivered',
    LeadStatus.lost => 'lost',
    _ => throw ArgumentError('Unsupported fixture status'),
  };
  final end = created.add(const Duration(days: 2));
  return Lead(
    id: id,
    customerName: id,
    phone: id,
    source: source,
    modelInterested: model,
    status: LeadStatusValue.fromRaw(raw),
    assignedTo: repId,
    branchId: branchId,
    createdAt: created,
    lastActivityAt: end,
    statusHistory: [
      LeadStatusHistoryEntry(
        status: LeadStatusValue.fromRaw('new'),
        timestamp: created,
        note: null,
      ),
      if (status == LeadStatus.contacted)
        LeadStatusHistoryEntry(
          status: LeadStatusValue.fromRaw('contacted'),
          timestamp: end,
          note: null,
        ),
      if (status == LeadStatus.delivered) ...[
        LeadStatusHistoryEntry(
          status: LeadStatusValue.fromRaw('order_placed'),
          timestamp: created.add(const Duration(days: 1)),
          note: null,
        ),
        LeadStatusHistoryEntry(
          status: LeadStatusValue.fromRaw('delivered'),
          timestamp: end,
          note: null,
        ),
      ],
      if (status == LeadStatus.lost)
        LeadStatusHistoryEntry(
          status: LeadStatusValue.fromRaw('lost'),
          timestamp: end,
          note: null,
        ),
    ],
    expectedCloseDate: created.add(const Duration(days: 10)),
    dealValue: 100,
    lostReason: status == LeadStatus.lost ? 'Fixture reason' : null,
  );
}

DealershipDataset _insightDataset() {
  final leads = <Lead>[
    ...List.generate(
      20,
      (index) => lead(
        id: 'weak-$index',
        status: index < 2 ? LeadStatus.delivered : LeadStatus.lost,
        journey: index < 2
            ? deliveredJourney()
            : [
                history(LeadStatus.newLead, day(1)),
                history(LeadStatus.contacted, day(2)),
                history(LeadStatus.lost, day(4)),
              ],
        branchId: 'B1',
        repId: 'R1',
        lostReason: index < 2 ? null : 'Fixture reason',
      ),
    ),
    ...List.generate(
      20,
      (index) => lead(
        id: 'normal-$index',
        status: index < 15 ? LeadStatus.delivered : LeadStatus.lost,
        journey: index < 15
            ? deliveredJourney()
            : [
                history(LeadStatus.newLead, day(1)),
                history(LeadStatus.contacted, day(2)),
                history(LeadStatus.testDrive, day(3)),
                history(LeadStatus.lost, day(4)),
              ],
        branchId: 'B2',
        repId: 'R2',
        lostReason: index < 15 ? null : 'Fixture reason',
      ),
    ),
  ];
  return dataset(leads: leads);
}
