import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yoyota_dealers/data/models/dealership_models.dart';
import 'package:yoyota_dealers/data/parsing/dealership_dataset_parser.dart';
import 'package:yoyota_dealers/data/validation/validation.dart';
import 'package:yoyota_dealers/domain/indexes/dealership_dataset_indexes.dart';

import '../fixtures/canonical_fixture.dart';

void main() {
  const parser = DealershipDatasetParser();

  test('successfully parses typed entities and nullable values', () {
    final result = parser.parse(canonicalDatasetJson());

    expect(result.isCompatible, isTrue);
    expect(result.report.issues, isEmpty);
    final dataset = result.dataset!;
    expect(dataset.metadata.generatedAt, isA<DateTime>());
    expect(dataset.branches.single, isA<Branch>());
    expect(dataset.salesReps.single.role.value, SalesRepRole.salesOfficer);
    expect(dataset.leads.single.source, isNull);
    expect(dataset.leads.single.lostReason, isNull);
    expect(dataset.leads.single.statusHistory.first.note, isNull);
    expect(dataset.targets.single.month, DateTime(2025, 7));
  });

  test('preserves unknown enum values and reports warnings', () {
    final map = canonicalDatasetMap();
    final lead = (map['leads']! as List).single as Map<String, Object?>;
    lead['status'] = 'awaiting_finance';
    final history = lead['status_history']! as List;
    (history.last as Map<String, Object?>)['status'] = 'awaiting_finance';

    final result = parser.parse(jsonEncode(map));

    expect(result.dataset!.leads.single.status.value, LeadStatus.unknown);
    expect(result.dataset!.leads.single.status.rawValue, 'awaiting_finance');
    expect(
      result.report.warnings
          .where((issue) => issue.code == ValidationCode.unknownEnumValue),
      hasLength(2),
    );
  });

  test('reports bad references and duplicate IDs as validation errors', () {
    final map = canonicalDatasetMap();
    final branches = map['branches']! as List;
    branches.add(branches.single);
    final lead = (map['leads']! as List).single as Map<String, Object?>;
    lead['branch_id'] = 'MISSING_BRANCH';
    lead['assigned_to'] = 'MISSING_REP';
    (map['deliveries']! as List).add({
      'lead_id': 'MISSING_LEAD',
      'order_date': '2025-07-01',
      'delivery_date': '2025-07-10',
      'days_to_deliver': 9,
      'delay_reason': null,
    });
    ((map['targets']! as List).single as Map<String, Object?>)['branch_id'] =
        'MISSING_BRANCH';

    final result = parser.parse(jsonEncode(map));
    final codes = result.report.errors.map((issue) => issue.code).toSet();

    expect(codes, contains(ValidationCode.duplicateId));
    expect(codes, contains(ValidationCode.missingBranchReference));
    expect(codes, contains(ValidationCode.missingSalesRepReference));
    expect(codes, contains(ValidationCode.missingLeadReference));
  });

  test('reports malformed dates as fatal parsing errors', () {
    final map = canonicalDatasetMap();
    final lead = (map['leads']! as List).single as Map<String, Object?>;
    lead['created_at'] = 'not-a-date';

    final result = parser.parse(jsonEncode(map));

    expect(result.dataset, isNull);
    expect(result.report.fatalParsingErrors, hasLength(1));
    expect(
      result.report.fatalParsingErrors.single.code,
      ValidationCode.malformedDate,
    );
  });

  test('reports malformed numeric fields as fatal parsing errors', () {
    final map = canonicalDatasetMap();
    final lead = (map['leads']! as List).single as Map<String, Object?>;
    lead['deal_value'] = '1000';

    final result = parser.parse(jsonEncode(map));

    expect(result.dataset, isNull);
    expect(
      result.report.fatalParsingErrors.single.code,
      ValidationCode.malformedNumber,
    );
  });

  test('reports history ordering, empty history, and negatives', () {
    final map = canonicalDatasetMap();
    final lead = (map['leads']! as List).single as Map<String, Object?>;
    final history = lead['status_history']! as List;
    (history.last as Map<String, Object?>)['timestamp'] =
        '2025-06-30T09:00:00Z';
    lead['deal_value'] = -1;

    final result = parser.parse(jsonEncode(map));
    expect(
      result.report.errors.map((issue) => issue.code),
      containsAll([
        ValidationCode.unorderedStatusHistory,
        ValidationCode.negativeValue,
      ]),
    );

    lead['status_history'] = <Object?>[];
    final emptyResult = parser.parse(jsonEncode(map));
    expect(
      emptyResult.report.errors.map((issue) => issue.code),
      contains(ValidationCode.emptyStatusHistory),
    );
  });

  test('reports current status conflict without repairing it', () {
    final map = canonicalDatasetMap();
    final lead = (map['leads']! as List).single as Map<String, Object?>;
    lead['status'] = 'lost';

    final result = parser.parse(jsonEncode(map));

    expect(result.dataset!.leads.single.status.value, LeadStatus.lost);
    expect(
      result.report.warnings.single.code,
      ValidationCode.currentStatusConflict,
    );
  });

  test('supplied dataset loads and indexes relationships', () async {
    final source =
        await File('assets/data/dealership_data.json').readAsString();
    final result = parser.parse(source);

    expect(result.dataset, isNotNull);
    expect(result.report.fatalParsingErrors, isEmpty);
    expect(result.report.errors, isEmpty);
    expect(result.report.warnings, hasLength(14));

    final indexes = DealershipDatasetIndexes.build(result.dataset!);
    expect(indexes.branchById, hasLength(5));
    expect(indexes.repById, hasLength(30));
    expect(indexes.leadById, hasLength(510));
    expect(indexes.repsByBranch['B1'], hasLength(7));
    expect(indexes.leadsByBranch['B1'], hasLength(97));
    expect(indexes.leadsByRep['SR2'], hasLength(19));
  });
}
