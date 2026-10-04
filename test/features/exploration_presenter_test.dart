import 'package:flutter_test/flutter_test.dart';
import 'package:yoyota_dealers/analytics/services/performance_explorer.dart';
import 'package:yoyota_dealers/application/analysis/analysis_controller.dart';
import 'package:yoyota_dealers/data/models/dealership_models.dart';
import 'package:yoyota_dealers/features/exploration/exploration_presenter.dart';

import '../fixtures/analytics_fixture.dart';

void main() {
  test('conversion ranking labels supported high and low results precisely',
      () {
    final controller = AnalysisController(dataset: _supportedDataset());
    addTearDown(controller.dispose);

    final ranking = presentComparisonRanking(
      data: controller.explore(ComparisonDimension.branch),
      metric: ComparisonMetric.conversion,
      ascending: false,
    );
    final high = ranking.rows.first;
    final low = ranking.rows.last;

    expect(high.slice.id, 'B1');
    expect(high.rank, 1);
    expect(high.badge, 'Highest resolved conversion');
    expect(high.tone, ComparisonRankTone.positive);
    expect(high.supportLabel, contains('12 resolved leads'));
    expect(low.slice.id, 'B2');
    expect(low.badge, 'Lowest resolved conversion');
    expect(low.tone, ComparisonRankTone.attention);
  });

  test('more recorded losses receives attention rather than a positive badge',
      () {
    final controller = AnalysisController(dataset: _supportedDataset());
    addTearDown(controller.dispose);

    final ranking = presentComparisonRanking(
      data: controller.explore(ComparisonDimension.branch),
      metric: ComparisonMetric.lostCount,
      ascending: false,
    );

    expect(ranking.rows.first.slice.id, 'B2');
    expect(ranking.rows.first.badge, 'Most recorded losses');
    expect(ranking.rows.first.tone, ComparisonRankTone.attention);
    expect(ranking.rows.last.badge, 'Fewest recorded losses');
    expect(ranking.rows.last.tone, ComparisonRankTone.positive);
  });

  test('tiny samples and a single comparable item do not create winners', () {
    final source = dataset(leads: [
      lead(
        id: 'small-delivered',
        branchId: 'B1',
        repId: 'R1',
        status: LeadStatus.delivered,
        journey: deliveredJourney(),
      ),
      lead(
        id: 'small-lost',
        branchId: 'B2',
        repId: 'R2',
        status: LeadStatus.lost,
        journey: [
          history(LeadStatus.newLead, day(1)),
          history(LeadStatus.lost, day(2)),
        ],
      ),
    ]);
    final controller = AnalysisController(dataset: source);
    addTearDown(controller.dispose);

    final small = presentComparisonRanking(
      data: controller.explore(ComparisonDimension.branch),
      metric: ComparisonMetric.conversion,
      ascending: false,
    );
    expect(small.rows.every((row) => row.badge == null), isTrue);
    expect(small.rows.every((row) => row.rank == null), isTrue);
    expect(small.rows.first.supportLabel, contains('insufficient support'));

    controller.setBranch('B1');
    final single = presentComparisonRanking(
      data: controller.explore(ComparisonDimension.branch),
      metric: ComparisonMetric.leads,
      ascending: false,
    );
    expect(single.rows, hasLength(1));
    expect(single.rows.single.badge, isNull);
  });

  test('unsupported equal values never inherit supported extreme badges', () {
    final controller = AnalysisController(
        dataset: dataset(leads: [
      for (final source in [
        'supported-high',
        'supported-low',
        'tiny-high',
        'tiny-low'
      ])
        for (var i = 0; i < (source.startsWith('tiny') ? 1 : 12); i++)
          lead(
            id: '$source-$i',
            source: source,
            status: source.endsWith('high')
                ? LeadStatus.delivered
                : LeadStatus.lost,
            journey: source.endsWith('high')
                ? deliveredJourney()
                : [
                    history(LeadStatus.newLead, day(1)),
                    history(LeadStatus.lost, day(2)),
                  ],
          ),
    ]));
    addTearDown(controller.dispose);
    for (final ascending in [false, true]) {
      final ranking = presentComparisonRanking(
        data: controller.explore(ComparisonDimension.source),
        metric: ComparisonMetric.conversion,
        ascending: ascending,
      );
      for (final row
          in ranking.rows.where((r) => r.slice.id!.startsWith('tiny'))) {
        expect(row.rank, isNull);
        expect(row.badge, isNull);
        expect(row.tone, isNull);
      }
      expect(ranking.rows.where((r) => r.badge != null), hasLength(2));
    }
  });

  test('equal results share a rank without a leading or low badge', () {
    final controller = AnalysisController(
        dataset: dataset(leads: [
      lead(
        id: 'b1',
        branchId: 'B1',
        repId: 'R1',
        status: LeadStatus.newLead,
        journey: [history(LeadStatus.newLead, day(1))],
      ),
      lead(
        id: 'b2',
        branchId: 'B2',
        repId: 'R2',
        status: LeadStatus.newLead,
        journey: [history(LeadStatus.newLead, day(1))],
      ),
    ]));
    addTearDown(controller.dispose);

    final ranking = presentComparisonRanking(
      data: controller.explore(ComparisonDimension.branch),
      metric: ComparisonMetric.leads,
      ascending: false,
    );

    expect(ranking.rows.every((row) => row.rank == 1), isTrue);
    expect(ranking.rows.every((row) => row.rankTied), isTrue);
    expect(ranking.rows.every((row) => row.badge == null), isTrue);
  });
}

DealershipDataset _supportedDataset() => dataset(leads: [
      for (var index = 0; index < 12; index++)
        lead(
          id: 'delivered-$index',
          branchId: 'B1',
          repId: 'R1',
          status: LeadStatus.delivered,
          journey: deliveredJourney(),
        ),
      for (var index = 0; index < 12; index++)
        lead(
          id: 'lost-$index',
          branchId: 'B2',
          repId: 'R2',
          status: LeadStatus.lost,
          journey: [
            history(LeadStatus.newLead, day(1)),
            history(LeadStatus.lost, day(2)),
          ],
        ),
    ]);
