import 'package:flutter_test/flutter_test.dart';
import 'package:yoyota_dealers/analytics/services/lead_feature_engineer.dart';
import 'package:yoyota_dealers/data/models/dealership_models.dart';
import 'package:yoyota_dealers/insights/models/insight_engine_config.dart';
import 'package:yoyota_dealers/insights/models/management_insight.dart';
import 'package:yoyota_dealers/insights/services/deterministic_insight_engine.dart';

import '../fixtures/analytics_fixture.dart';

void main() {
  test('a clear branch anomaly triggers while a normal branch does not', () {
    final leads = <Lead>[
      ..._resolvedGroup(
        prefix: 'weak',
        branchId: 'B1',
        repId: 'R1',
        delivered: 2,
        lost: 18,
      ),
      ..._resolvedGroup(
        prefix: 'normal',
        branchId: 'B2',
        repId: 'R2',
        delivered: 15,
        lost: 5,
      ),
    ];
    final insights = _generate(leads);

    expect(
      insights.map((insight) => insight.id),
      contains('branch.low_conversion.B1'),
    );
    expect(
      insights.map((insight) => insight.id),
      isNot(contains('branch.low_conversion.B2')),
    );
  });

  test('tiny comparison samples are suppressed', () {
    final leads = <Lead>[
      ..._resolvedGroup(
        prefix: 'network',
        branchId: 'B1',
        repId: 'R1',
        delivered: 20,
        lost: 0,
      ),
      ..._resolvedGroup(
        prefix: 'tiny',
        branchId: 'B2',
        repId: 'R2',
        delivered: 0,
        lost: 1,
      ),
    ];

    final insights = _generate(leads);

    expect(
      insights.map((insight) => insight.id),
      isNot(contains('branch.low_conversion.B2')),
    );
  });

  test('stale active pipeline generates an explainable insight', () {
    final leads = List.generate(
      6,
      (index) => lead(
        id: 'active-$index',
        status: LeadStatus.negotiation,
        journey: [
          history(LeadStatus.newLead, day(1)),
          history(LeadStatus.contacted, day(2)),
          history(LeadStatus.testDrive, day(3)),
          history(LeadStatus.negotiation, day(4)),
        ],
        lastActivityAt: day(4),
        value: 100 + index,
      ),
    );
    const engine = DeterministicInsightEngine(
      config: InsightEngineConfig(minimumStageLeads: 5),
    );
    final analytical = const LeadFeatureEngineer()
        .build(dataset(leads: leads), snapshotDate: day(31));

    final insight = engine
        .generate(analytical, limit: 100)
        .singleWhere((item) => item.id == 'pipeline.stale_active');

    expect(insight.affectedLeadCount, 6);
    expect(insight.affectedLeadIds, hasLength(6));
    expect(insight.suggestedInvestigation, isNotEmpty);
    expect(insight.generationReason, contains('threshold'));
  });

  test('higher deal-value impact increases ranking for equivalent findings',
      () {
    final leads = <Lead>[
      ..._lostBeforeContact('high-value', 'high', 15, 1000),
      ..._lostBeforeContact('low-value', 'low', 15, 10),
      ...List.generate(
        30,
        (index) => lead(
          id: 'good-$index',
          status: LeadStatus.delivered,
          journey: deliveredJourney(),
          source: 'good',
          value: 100,
        ),
      ),
    ];
    final insights = _generate(leads);
    final high = insights.singleWhere(
        (insight) => insight.id == 'source.low_contact.high-value');
    final low = insights
        .singleWhere((insight) => insight.id == 'source.low_contact.low-value');

    expect(high.affectedLeadCount, low.affectedLeadCount);
    expect(high.rankScore, greaterThan(low.rankScore));
    expect(high.rankingFactors['affected_value'],
        greaterThan(low.rankingFactors['affected_value']!));
  });

  test('affected evidence IDs are exact, unique, and reconcile to count', () {
    final leads = <Lead>[
      ..._resolvedGroup(
        prefix: 'weak',
        branchId: 'B1',
        repId: 'R1',
        delivered: 2,
        lost: 18,
      ),
      ..._resolvedGroup(
        prefix: 'normal',
        branchId: 'B2',
        repId: 'R2',
        delivered: 15,
        lost: 5,
      ),
    ];
    final sourceIds = leads.map((item) => item.id).toSet();
    final insights = _generate(leads);

    for (final insight in insights) {
      expect(insight.affectedLeadIds.toSet(),
          hasLength(insight.affectedLeadCount));
      expect(
        insight.affectedLeadIds.every(sourceIds.contains),
        isTrue,
        reason: insight.id,
      );
    }
  });

  test('default overview prevents one rule family from crowding the list', () {
    final leads = <Lead>[
      ..._lostBeforeContact('source-a', 'a', 15, 100),
      ..._lostBeforeContact('source-b', 'b', 15, 100),
      ...List.generate(
        30,
        (index) => lead(
          id: 'good-$index',
          status: LeadStatus.delivered,
          journey: deliveredJourney(),
          source: 'good',
        ),
      ),
    ];
    final analytical = const LeadFeatureEngineer()
        .build(dataset(leads: leads), snapshotDate: day(31));

    final overview = const DeterministicInsightEngine().generate(analytical);
    final families = overview.map((insight) {
      final parts = insight.id.split('.');
      return '${parts[0]}.${parts[1]}';
    }).toList();
    final familyCounts = <String, int>{};
    for (final family in families) {
      familyCounts.update(family, (count) => count + 1, ifAbsent: () => 1);
    }

    expect(familyCounts.values.every((count) => count <= 2), isTrue);
  });
}

List<ManagementInsight> _generate(List<Lead> leads) {
  final analytical = const LeadFeatureEngineer()
      .build(dataset(leads: leads), snapshotDate: day(31));
  return const DeterministicInsightEngine().generate(analytical, limit: 100);
}

List<Lead> _resolvedGroup({
  required String prefix,
  required String branchId,
  required String repId,
  required int delivered,
  required int lost,
}) =>
    [
      ...List.generate(
        delivered,
        (index) => lead(
          id: '$prefix-delivered-$index',
          status: LeadStatus.delivered,
          journey: deliveredJourney(),
          branchId: branchId,
          repId: repId,
          source: '$prefix-source',
        ),
      ),
      ...List.generate(
        lost,
        (index) => lead(
          id: '$prefix-lost-$index',
          status: LeadStatus.lost,
          journey: [
            history(LeadStatus.newLead, day(1)),
            history(LeadStatus.contacted, day(2)),
            history(LeadStatus.testDrive, day(3)),
            history(LeadStatus.lost, day(5)),
          ],
          branchId: branchId,
          repId: repId,
          source: '$prefix-source',
          lostReason: 'Fixture reason',
        ),
      ),
    ];

List<Lead> _lostBeforeContact(
  String source,
  String prefix,
  int count,
  num value,
) =>
    List.generate(
      count,
      (index) => lead(
        id: '$prefix-$index',
        status: LeadStatus.lost,
        journey: [
          history(LeadStatus.newLead, day(1)),
          history(LeadStatus.lost, day(2)),
        ],
        source: source,
        value: value,
        lostReason: 'Fixture reason',
      ),
    );
