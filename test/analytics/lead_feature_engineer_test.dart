import 'package:flutter_test/flutter_test.dart';
import 'package:yoyota_dealers/analytics/models/analytical_lead.dart';
import 'package:yoyota_dealers/analytics/services/lead_feature_engineer.dart';
import 'package:yoyota_dealers/data/models/dealership_models.dart';

import '../fixtures/analytics_fixture.dart';

void main() {
  const engineer = LeadFeatureEngineer();

  test('derives a complete delivered journey and maturity threshold', () {
    final source = dataset(leads: [
      lead(
        id: 'complete',
        status: LeadStatus.delivered,
        journey: deliveredJourney(),
      ),
    ]);
    final result = engineer.build(source, snapshotDate: day(20));
    final record = result.leads.single;

    expect(record.reachedContacted, isTrue);
    expect(record.reachedTestDrive, isTrue);
    expect(record.reachedNegotiation, isTrue);
    expect(record.reachedOrderPlaced, isTrue);
    expect(record.reachedDelivered, isTrue);
    expect(record.newToContacted, const Duration(days: 1));
    expect(record.orderToDelivery, const Duration(days: 2));
    expect(record.creationToDelivery, const Duration(days: 6));
    expect(record.currentFunnelStage, FunnelStage.delivered);
    expect(record.highestSuccessfulStage, FunnelStage.delivered);
    expect(record.isResolved, isTrue);
    expect(record.isDelivered, isTrue);
    expect(result.context.maturityDuration, const Duration(days: 6));
    expect(record.isMatureForOutcomeComparison, isTrue);
    expect(record.repTenureAtCreation, const Duration(days: 366));
  });

  test('attributes a lead lost at new', () {
    final record = engineer
        .build(
            dataset(leads: [
              lead(
                id: 'lost-new',
                status: LeadStatus.lost,
                journey: [
                  history(LeadStatus.newLead, day(1)),
                  history(LeadStatus.lost, day(2)),
                ],
                lostReason: 'No response',
              ),
            ]),
            snapshotDate: day(10))
        .leads
        .single;

    expect(record.lostFromStage, FunnelStage.newLead);
    expect(record.reachedContacted, isFalse);
    expect(record.daysInCurrentStage, 1);
  });

  test('attributes a lead lost after contacted', () {
    final record = engineer
        .build(
            dataset(leads: [
              lead(
                id: 'lost-contacted',
                status: LeadStatus.lost,
                journey: [
                  history(LeadStatus.newLead, day(1)),
                  history(LeadStatus.contacted, day(2)),
                  history(LeadStatus.lost, day(5)),
                ],
              ),
            ]),
            snapshotDate: day(10))
        .leads
        .single;
    expect(record.lostFromStage, FunnelStage.contacted);
    expect(record.reachedTestDrive, isFalse);
  });

  test('attributes a lead lost after test drive', () {
    final record = engineer
        .build(
            dataset(leads: [
              lead(
                id: 'lost-test',
                status: LeadStatus.lost,
                journey: [
                  history(LeadStatus.newLead, day(1)),
                  history(LeadStatus.contacted, day(2)),
                  history(LeadStatus.testDrive, day(3)),
                  history(LeadStatus.lost, day(6)),
                ],
              ),
            ]),
            snapshotDate: day(10))
        .leads
        .single;
    expect(record.lostFromStage, FunnelStage.testDrive);
  });

  test('derives an active negotiation using the analytical snapshot', () {
    final record = engineer
        .build(
            dataset(leads: [
              lead(
                id: 'negotiation',
                status: LeadStatus.negotiation,
                journey: [
                  history(LeadStatus.newLead, day(1)),
                  history(LeadStatus.contacted, day(2)),
                  history(LeadStatus.testDrive, day(3)),
                  history(LeadStatus.negotiation, day(5)),
                ],
              ),
            ]),
            snapshotDate: day(10))
        .leads
        .single;
    expect(record.isActive, isTrue);
    expect(record.currentFunnelStage, FunnelStage.negotiation);
    expect(record.daysInCurrentStage, 5);
    expect(record.daysSinceLastActivity, 5);
  });

  test('derives an overdue active order without calling it lost', () {
    final record = engineer
        .build(
            dataset(leads: [
              lead(
                id: 'order',
                status: LeadStatus.orderPlaced,
                journey: [
                  history(LeadStatus.newLead, day(1)),
                  history(LeadStatus.orderPlaced, day(5)),
                ],
                expectedCloseDate: day(7),
              ),
            ]),
            snapshotDate: day(10))
        .leads
        .single;
    expect(record.isActive, isTrue);
    expect(record.isLost, isFalse);
    expect(record.expectedCloseOverdue, isTrue);
    expect(record.expectedCloseSlippage, const Duration(days: 3));
  });

  test('does not invent a missing optional transition', () {
    final record = engineer
        .build(
            dataset(leads: [
              lead(
                id: 'skip-contact',
                status: LeadStatus.testDrive,
                journey: [
                  history(LeadStatus.newLead, day(1)),
                  history(LeadStatus.testDrive, day(3)),
                ],
              ),
            ]),
            snapshotDate: day(10))
        .leads
        .single;
    expect(record.reachedContacted, isFalse);
    expect(record.contactedAt, isNull);
    expect(record.contactedToTestDrive, isNull);
    expect(record.reachedTestDrive, isTrue);
  });

  test('flags invalid chronology and suppresses negative durations', () {
    final record = engineer
        .build(
            dataset(leads: [
              lead(
                id: 'bad-order',
                status: LeadStatus.contacted,
                journey: [
                  history(LeadStatus.newLead, day(3)),
                  history(LeadStatus.contacted, day(2)),
                ],
                createdAt: day(3),
              ),
            ]),
            snapshotDate: day(10))
        .leads
        .single;
    expect(record.hasValidChronology, isFalse);
    expect(record.newToContacted, isNull);
  });

  test('default snapshot is the latest business timestamp and is overridable',
      () {
    final source = dataset(leads: [
      lead(
        id: 'active',
        status: LeadStatus.newLead,
        journey: [history(LeadStatus.newLead, day(4))],
        createdAt: day(4),
      ),
    ]);
    expect(engineer.build(source).context.snapshotDate, day(4));
    expect(
      engineer.build(source, snapshotDate: day(12)).context.snapshotDate,
      day(12),
    );
  });
}
