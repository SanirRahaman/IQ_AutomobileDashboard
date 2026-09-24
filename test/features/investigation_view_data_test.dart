import 'package:flutter_test/flutter_test.dart';
import 'package:yoyota_dealers/application/analysis/analysis_controller.dart';
import 'package:yoyota_dealers/data/models/dealership_models.dart';
import 'package:yoyota_dealers/features/investigation/investigation_view_data.dart';

import '../fixtures/analytics_fixture.dart';

void main() {
  test('branch count benchmarks use a peer median rather than network totals',
      () {
    final source = _comparisonDataset();
    final scoped = AnalysisController(dataset: source)..setBranch('B1');
    final network = AnalysisController(dataset: source);
    addTearDown(scoped.dispose);
    addTearDown(network.dispose);

    final view = const InvestigationPresenter().branch(
      scoped: scoped,
      network: network,
    );

    expect(
      view.kpis.singleWhere((row) => row.label == 'Lead volume').benchmark,
      '4 median branch',
    );
  });

  test('rep count benchmarks use the median active peer', () {
    final source = _comparisonDataset();
    final scoped = AnalysisController(dataset: source)..setSalesRep('R1');
    final branch = AnalysisController(dataset: source)..setBranch('B1');
    addTearDown(scoped.dispose);
    addTearDown(branch.dispose);

    final view = const InvestigationPresenter().rep(
      scoped: scoped,
      branch: branch,
    );

    expect(
      view.kpis.singleWhere((row) => row.label == 'Workload').benchmark,
      '2 median active rep',
    );
  });
}

DealershipDataset _comparisonDataset() => dataset(leads: [
      lead(
        id: 'b1-r1',
        status: LeadStatus.contacted,
        repId: 'R1',
        branchId: 'B1',
        journey: [
          history(LeadStatus.newLead, day(1)),
          history(LeadStatus.contacted, day(2)),
        ],
      ),
      for (var index = 0; index < 3; index++)
        lead(
          id: 'b1-manager-$index',
          status: LeadStatus.contacted,
          repId: 'M1',
          branchId: 'B1',
          journey: [
            history(LeadStatus.newLead, day(3 + index * 2)),
            history(LeadStatus.contacted, day(4 + index * 2)),
          ],
        ),
      for (var index = 0; index < 3; index++)
        lead(
          id: 'b2-r2-$index',
          status: LeadStatus.contacted,
          repId: 'R2',
          branchId: 'B2',
          journey: [
            history(LeadStatus.newLead, day(10 + index * 2)),
            history(LeadStatus.contacted, day(11 + index * 2)),
          ],
        ),
    ]);
