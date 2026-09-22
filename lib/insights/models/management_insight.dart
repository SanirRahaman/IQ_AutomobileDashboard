import 'dart:collection';

enum InsightCategory {
  funnel,
  branch,
  rep,
  source,
  vehicle,
  pipeline,
  delivery,
  dataQuality,
  positiveOpportunity,
}

enum InsightSeverity { critical, warning, opportunity, positive, informational }

enum EvidenceStrength { weak, moderate, strong }

enum MetricUnit { count, rate, days, value, ratio }

final class InsightMetric {
  const InsightMetric({
    required this.key,
    required this.label,
    required this.value,
    required this.unit,
    this.numerator,
    this.denominator,
  });

  final String key;
  final String label;
  final double value;
  final MetricUnit unit;
  final int? numerator;
  final int? denominator;

  Map<String, Object?> toJson() => {
        'key': key,
        'label': label,
        'value': value,
        'unit': unit.name,
        if (numerator != null) 'numerator': numerator,
        if (denominator != null) 'denominator': denominator,
      };
}

final class InsightBenchmark {
  const InsightBenchmark({
    required this.label,
    required this.value,
    required this.unit,
    required this.method,
    required this.sampleSize,
  });

  final String label;
  final double value;
  final MetricUnit unit;
  final String method;
  final int sampleSize;

  Map<String, Object?> toJson() => {
        'label': label,
        'value': value,
        'unit': unit.name,
        'method': method,
        'sample_size': sampleSize,
      };
}

final class InsightDimensions {
  InsightDimensions({
    Iterable<String> branchIds = const [],
    Iterable<String> repIds = const [],
    Iterable<String?> sourceIds = const [],
    Iterable<String> modelIds = const [],
  })  : branchIds = UnmodifiableListView(branchIds.toSet()),
        repIds = UnmodifiableListView(repIds.toSet()),
        sourceIds = UnmodifiableListView(sourceIds.toSet()),
        modelIds = UnmodifiableListView(modelIds.toSet());

  final List<String> branchIds;
  final List<String> repIds;
  final List<String?> sourceIds;
  final List<String> modelIds;

  Map<String, Object?> toJson() => {
        'branch_ids': branchIds,
        'rep_ids': repIds,
        'source_ids': sourceIds,
        'model_ids': modelIds,
      };
}

final class ManagementInsight {
  ManagementInsight({
    required this.id,
    required this.category,
    required this.severity,
    required this.title,
    required this.finding,
    required this.businessSignificance,
    required this.observedMetric,
    required this.benchmark,
    required this.absoluteDifference,
    required this.relativeDifference,
    required this.affectedLeadCount,
    required this.affectedDealValue,
    required this.evidenceStrength,
    required this.dimensions,
    required Iterable<String> affectedLeadIds,
    required this.suggestedInvestigation,
    required this.generationReason,
    required this.rankScore,
    required Map<String, double> rankingFactors,
  })  : affectedLeadIds = UnmodifiableListView(affectedLeadIds.toSet()),
        rankingFactors = UnmodifiableMapView(rankingFactors);

  final String id;
  final InsightCategory category;
  final InsightSeverity severity;
  final String title;
  final String finding;
  final String businessSignificance;
  final InsightMetric observedMetric;
  final InsightBenchmark? benchmark;
  final double? absoluteDifference;
  final double? relativeDifference;
  final int affectedLeadCount;
  final num? affectedDealValue;
  final EvidenceStrength evidenceStrength;
  final InsightDimensions dimensions;
  final List<String> affectedLeadIds;
  final String suggestedInvestigation;
  final String generationReason;
  final double rankScore;
  final Map<String, double> rankingFactors;

  Map<String, Object?> toJson() => {
        'id': id,
        'category': category.name,
        'severity': severity.name,
        'title': title,
        'finding': finding,
        'business_significance': businessSignificance,
        'observed_metric': observedMetric.toJson(),
        'benchmark': benchmark?.toJson(),
        'absolute_difference': absoluteDifference,
        'relative_difference': relativeDifference,
        'affected_lead_count': affectedLeadCount,
        'affected_deal_value': affectedDealValue,
        'evidence_strength': evidenceStrength.name,
        'dimensions': dimensions.toJson(),
        'affected_lead_ids': affectedLeadIds,
        'suggested_investigation': suggestedInvestigation,
        'generation_reason': generationReason,
        'rank_score': rankScore,
        'ranking_factors': rankingFactors,
      };
}
