import 'dart:convert';
import 'dart:io';

import 'package:yoyota_dealers/analytics/services/lead_feature_engineer.dart';
import 'package:yoyota_dealers/data/parsing/dealership_dataset_parser.dart';
import 'package:yoyota_dealers/insights/services/deterministic_insight_engine.dart';

Future<void> main(List<String> arguments) async {
  final path =
      arguments.isEmpty ? 'assets/data/dealership_data.json' : arguments.first;
  final source = await File(path).readAsString();
  final parsed = const DealershipDatasetParser().parse(source);
  if (!parsed.isCompatible || parsed.dataset == null) {
    stderr.writeln(const JsonEncoder.withIndent('  ').convert({
      'compatible': false,
      'issues': parsed.report.issues
          .map((issue) => {
                'severity': issue.severity.name,
                'code': issue.code.name,
                'path': issue.path,
                'message': issue.message,
              })
          .toList(),
    }));
    exitCode = 1;
    return;
  }

  final analytical = const LeadFeatureEngineer().build(parsed.dataset!);
  final insights = const DeterministicInsightEngine().generate(
    analytical,
    validationReport: parsed.report,
  );
  stdout.writeln(const JsonEncoder.withIndent('  ').convert({
    'dataset': path,
    'snapshot_date': analytical.context.snapshotDate.toIso8601String(),
    'maturity_duration_days':
        analytical.context.maturityDuration?.inHours.toDouble() == null
            ? null
            : analytical.context.maturityDuration!.inHours / 24,
    'insight_count': insights.length,
    'insights': insights.map((insight) => insight.toJson()).toList(),
  }));
}
