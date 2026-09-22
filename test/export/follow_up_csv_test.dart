import 'package:flutter_test/flutter_test.dart';
import 'package:yoyota_dealers/analytics/services/lead_feature_engineer.dart';
import 'package:yoyota_dealers/application/export/follow_up_csv.dart';
import 'package:yoyota_dealers/data/models/dealership_models.dart';
import '../fixtures/analytics_fixture.dart';

void main() {
  final data = dataset(leads: [
    lead(id: 'active', status: LeadStatus.contacted, journey: [
      history(LeadStatus.newLead, day(1)),
      history(LeadStatus.contacted, day(2))
    ]),
    lead(
        id: 'lost',
        status: LeadStatus.lost,
        journey: [history(LeadStatus.lost, day(3))]),
    lead(
        id: 'other',
        status: LeadStatus.newLead,
        branchId: 'B2',
        journey: [history(LeadStatus.newLead, day(1))])
  ]);
  final records = const LeadFeatureEngineer().build(data).leads;
  test('follow-up intersects evidence and filtered scope, excludes resolved',
      () {
    final csv = const FollowUpCsv().create(
        dataset: data,
        scopedRecords: records.where((r) => r.branchId == 'B1'),
        requestedIds: ['active', 'lost', 'other', 'missing', 'active'],
        label: 'Branch One active opportunities');
    expect(csv.count, 1);
    expect(csv.content, contains('Customer active'));
    expect(csv.content, isNot(contains('Customer lost')));
    expect(csv.content, isNot(contains('Customer other')));
    expect(csv.filename, 'branch-one-active-opportunities-follow-up.csv');
    expect(csv.content, startsWith('\uFEFF'));
    expect(csv.content, contains('Representative'));
    expect(csv.content, contains('Data as of'));
  });
  test(
      'all records export keeps terminal statuses; escapes CSV and spreadsheet formulas',
      () {
    final csv = const FollowUpCsv().create(
        dataset: data,
        scopedRecords: records,
        requestedIds: ['lost'],
        label: 'Findings',
        activeOnly: false,
        reason: '=SUM(1,2)\n"review"');
    expect(csv.count, 1);
    expect(csv.content, contains('"lost"'));
    expect(csv.content, contains('"\'=SUM(1,2)\n""review"""'));
  });
}
