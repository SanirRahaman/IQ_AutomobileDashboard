import 'package:flutter_test/flutter_test.dart';
import 'package:yoyota_dealers/application/analysis/analysis_controller.dart';
import 'package:yoyota_dealers/application/analysis/analysis_filters.dart';
import 'package:yoyota_dealers/application/export/follow_up_csv.dart';
import 'package:yoyota_dealers/data/models/dealership_models.dart';

import '../fixtures/analytics_fixture.dart';

void main() {
  final data = dataset(leads: [
    lead(id: 'won', status: LeadStatus.delivered, journey: deliveredJourney()),
    lead(
        id: 'open',
        status: LeadStatus.orderPlaced,
        expectedCloseDate: day(20),
        journey: [
          history(LeadStatus.newLead, day(1)),
          history(LeadStatus.orderPlaced, day(5))
        ]),
    lead(
        id: 'lost',
        status: LeadStatus.lost,
        branchId: 'B2',
        repId: 'R2',
        journey: [
          history(LeadStatus.newLead, day(1)),
          history(LeadStatus.lost, day(31))
        ]),
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
        deliveryDate: day(8),
        daysToDeliver: 3,
        delayReason: 'Recorded delay'),
  ]);

  test('follow-up evidence counts overlapping attention signals once', () {
    final c = AnalysisController(dataset: data);
    addTearDown(c.dispose);
    expect(c.results.followUpLeadIds, ['open']);
    expect(c.results.deliveredOutcomeIds, ['won']);
    expect(c.results.lostOutcomeIds, ['lost']);
    expect(c.results.activeLeadIds, ['open']);
    c.setBranch('B2');
    expect(c.results.followUpLeadIds, isEmpty);
    expect(c.results.receivedLeadIds, ['lost']);
    c.setSalesRep('R1');
    expect(c.results.lostOutcomeIds, isEmpty);
    expect(c.results.receivedLeadIds, ['won', 'open']);
  });

  test(
      'delivery evidence and CSV retain events, including older leads and repeated lead references',
      () {
    final c = AnalysisController(
        dataset: data,
        initialFilters: AnalysisFilters(
            branchId: 'B1',
            dateRange: AnalysisDateRange(start: day(6), end: day(9))));
    addTearDown(c.dispose);
    expect(c.results.receivedLeadIds, isEmpty);
    expect(c.results.deliveredOutcomeIds, isEmpty);
    final performance = c.results.performance;
    expect(performance.deliveredCount, 2);
    expect(performance.deliveryRecords.length, 2);
    expect(c.results.deliveryScope.leads.single.id, 'won');
    final csv = const FollowUpCsv().createDeliveries(
        dataset: data,
        deliveries: performance.deliveryRecords,
        label: 'Branch One');
    expect(csv.count, 2);
    expect(csv.content, contains('2025-01-07'));
    expect(csv.content, contains('2025-01-08'));
    expect(csv.content, isNot(contains('Customer lost')));
    c.setDateRange(AnalysisDateRange(start: day(8), end: day(8)));
    expect(c.results.performance.deliveryRecords.single.deliveryDate, day(8));
  });
}
