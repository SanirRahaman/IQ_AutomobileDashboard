import '../../analytics/services/performance_explorer.dart';
import '../dashboard/dashboard_view_data.dart';

enum ComparisonRankTone { positive, attention, neutral }

final class RankedComparisonViewData {
  const RankedComparisonViewData({
    required this.slice,
    required this.rank,
    required this.rankTied,
    required this.badge,
    required this.tone,
    required this.fraction,
    required this.supportLabel,
  });

  final PerformanceSlice slice;
  final int? rank;
  final bool rankTied;
  final String? badge;
  final ComparisonRankTone? tone;
  final double fraction;
  final String supportLabel;
}

final class ComparisonRankingViewData {
  const ComparisonRankingViewData({
    required this.rows,
    required this.explanation,
  });

  final List<RankedComparisonViewData> rows;
  final String explanation;
}

List<ComparisonMetric> comparisonMetricsFor(ComparisonDimension dimension) =>
    switch (dimension) {
      ComparisonDimension.model => const [
          ComparisonMetric.deliveries,
          ComparisonMetric.leads,
          ComparisonMetric.conversion,
          ComparisonMetric.deliveredValue,
          ComparisonMetric.activeValue,
        ],
      ComparisonDimension.branch => const [
          ComparisonMetric.deliveries,
          ComparisonMetric.conversion,
          ComparisonMetric.activeValue,
          ComparisonMetric.staleValue,
          ComparisonMetric.deliveryDays,
        ],
      ComparisonDimension.representative => const [
          ComparisonMetric.leads,
          ComparisonMetric.conversion,
          ComparisonMetric.deliveries,
          ComparisonMetric.activeValue,
          ComparisonMetric.staleCount,
        ],
      ComparisonDimension.source => const [
          ComparisonMetric.leads,
          ComparisonMetric.contactRate,
          ComparisonMetric.testDriveRate,
          ComparisonMetric.conversion,
          ComparisonMetric.deliveries,
        ],
    };

ComparisonMetric defaultComparisonMetric(ComparisonDimension dimension) =>
    switch (dimension) {
      ComparisonDimension.model => ComparisonMetric.deliveries,
      ComparisonDimension.branch => ComparisonMetric.conversion,
      ComparisonDimension.representative => ComparisonMetric.conversion,
      ComparisonDimension.source => ComparisonMetric.leads,
    };

ComparisonRankingViewData presentComparisonRanking({
  required PerformanceExploration data,
  required ComparisonMetric metric,
  required bool ascending,
}) {
  final displayRows = data.ranked(metric, ascending: ascending);
  final supported = data.rows
      .where((row) => row.value(metric) != null && _supportsRank(row, metric))
      .toList()
    ..sort((left, right) {
      final comparison = right.value(metric)!.compareTo(left.value(metric)!);
      return comparison == 0 ? left.label.compareTo(right.label) : comparison;
    });
  final ranks = <PerformanceSlice, int>{};
  final tieCounts = <num, int>{};
  num? previous;
  var rank = 0;
  for (var index = 0; index < supported.length; index++) {
    final value = supported[index].value(metric)!;
    if (previous == null || value != previous) rank = index + 1;
    ranks[supported[index]] = rank;
    tieCounts[value] = (tieCounts[value] ?? 0) + 1;
    previous = value;
  }
  final values = supported.map((row) => row.value(metric)!).toSet();
  final meaningfulExtremes = supported.length > 1 && values.length > 1;
  final high = meaningfulExtremes ? supported.first.value(metric) : null;
  final low = meaningfulExtremes ? supported.last.value(metric) : null;
  final maximum = data.rows.fold<double>(0, (current, row) {
    final value = row.value(metric)?.abs().toDouble() ?? 0;
    return value > current ? value : current;
  });

  return ComparisonRankingViewData(
    rows: displayRows.map((row) {
      final value = row.value(metric);
      final isHigh = ranks.containsKey(row) && high != null && value == high;
      final isLow = ranks.containsKey(row) && low != null && value == low;
      final tied = value != null && (tieCounts[value] ?? 0) > 1;
      return RankedComparisonViewData(
        slice: row,
        rank: ranks[row],
        rankTied: ranks[row] != null && tied,
        badge: isHigh
            ? _extremeLabel(metric, high: true, tied: tied)
            : isLow
                ? _extremeLabel(metric, high: false, tied: tied)
                : null,
        tone: isHigh
            ? metric.highTone
            : isLow
                ? metric.lowTone
                : null,
        fraction: maximum == 0 || value == null ? 0 : value.abs() / maximum,
        supportLabel: _supportLabel(row, metric),
      );
    }).toList(growable: false),
    explanation: _rankingExplanation(metric, meaningfulExtremes),
  );
}

extension DimensionLabels on ComparisonDimension {
  String get label => switch (this) {
        ComparisonDimension.model => 'Vehicle models',
        ComparisonDimension.branch => 'Branches',
        ComparisonDimension.representative => 'Representatives',
        ComparisonDimension.source => 'Lead sources',
      };
}

extension MetricLabels on ComparisonMetric {
  String get label => switch (this) {
        ComparisonMetric.deliveries => 'Delivered vehicles',
        ComparisonMetric.deliveredValue => 'Delivered deal value',
        ComparisonMetric.leads => 'Lead demand',
        ComparisonMetric.conversion => 'Resolved conversion',
        ComparisonMetric.activeCount => 'Active opportunities',
        ComparisonMetric.activeValue => 'Active opportunity value',
        ComparisonMetric.staleCount => 'Stale opportunities',
        ComparisonMetric.staleValue => 'Stale opportunity value',
        ComparisonMetric.overdueCount => 'Overdue expected close',
        ComparisonMetric.lostCount => 'Lost opportunities',
        ComparisonMetric.lostValue => 'Lost deal value',
        ComparisonMetric.averageValue => 'Average lead deal value',
        ComparisonMetric.medianValue => 'Median lead deal value',
        ComparisonMetric.contactRate => 'Contact rate',
        ComparisonMetric.testDriveRate => 'Test drive after contact',
        ComparisonMetric.closeRate => 'Order after test drive',
        ComparisonMetric.deliveryDays => 'Median delivery days',
      };
  String get definition => switch (this) {
        ComparisonMetric.deliveries =>
          'Delivery events dated within the selected period. One customer can have multiple delivery records.',
        ComparisonMetric.deliveredValue =>
          'Lead deal value linked to each delivery event in the selected period. This is recorded deal value, not profit or cash received.',
        ComparisonMetric.conversion =>
          'Delivered ÷ (delivered + lost), among leads created in the selected period. Active opportunities are excluded. Compare mature groups and read the denominator.',
        ComparisonMetric.activeCount ||
        ComparisonMetric.activeValue ||
        ComparisonMetric.staleCount ||
        ComparisonMetric.staleValue ||
        ComparisonMetric.overdueCount =>
          'Current active leads created in the selected period. Ageing and overdue dates use the dataset snapshot; this is not the pipeline as it stood at the end of the selected period.',
        ComparisonMetric.averageValue ||
        ComparisonMetric.medianValue =>
          'Deal values of all leads created in the selected period, including delivered, lost and active leads. No currency is specified.',
        ComparisonMetric.contactRate =>
          'Leads that reached contact ÷ all leads created in the selected period.',
        ComparisonMetric.testDriveRate =>
          'Contacted leads that reached test drive ÷ contacted leads, within the selected creation cohort.',
        ComparisonMetric.closeRate =>
          'Test-driven leads that reached order ÷ test-driven leads, within the selected creation cohort. An order is not a delivery.',
        ComparisonMetric.deliveryDays =>
          'Median recorded days from order to delivery for linked delivery events in the selected delivery period.',
        ComparisonMetric.lostCount ||
        ComparisonMetric.lostValue =>
          'Recorded lost outcomes among leads created in the selected period. Losses may have occurred later. Active leads are never counted as losses.',
        ComparisonMetric.leads =>
          'Leads created in the selected period, regardless of their current outcome.',
      };
  String format(num? value) {
    if (value == null) return 'Unavailable';
    if (isRate) return DashboardPresenter.formatRate(value.toDouble());
    if (this == ComparisonMetric.deliveryDays) {
      return '${value.toStringAsFixed(1)} days';
    }
    if (const [
      ComparisonMetric.deliveredValue,
      ComparisonMetric.activeValue,
      ComparisonMetric.staleValue,
      ComparisonMetric.lostValue,
      ComparisonMetric.averageValue,
      ComparisonMetric.medianValue
    ].contains(this)) {
      return DashboardPresenter.formatValue(value);
    }
    return DashboardPresenter.formatInteger(value.toInt());
  }

  ComparisonRankTone get highTone => switch (this) {
        ComparisonMetric.deliveries ||
        ComparisonMetric.deliveredValue ||
        ComparisonMetric.conversion ||
        ComparisonMetric.contactRate ||
        ComparisonMetric.testDriveRate ||
        ComparisonMetric.closeRate =>
          ComparisonRankTone.positive,
        ComparisonMetric.staleCount ||
        ComparisonMetric.staleValue ||
        ComparisonMetric.overdueCount ||
        ComparisonMetric.lostCount ||
        ComparisonMetric.lostValue ||
        ComparisonMetric.deliveryDays =>
          ComparisonRankTone.attention,
        _ => ComparisonRankTone.neutral,
      };

  ComparisonRankTone get lowTone => switch (highTone) {
        ComparisonRankTone.positive => ComparisonRankTone.attention,
        ComparisonRankTone.attention => ComparisonRankTone.positive,
        ComparisonRankTone.neutral => ComparisonRankTone.neutral,
      };
}

String sampleLabel(PerformanceSlice slice, ComparisonMetric metric) {
  final denominator = slice.denominator(metric);
  if (denominator != null) {
    return '$denominator ${metric == ComparisonMetric.conversion ? 'resolved' : 'eligible'} leads'
        '${metric == ComparisonMetric.conversion && !slice.mature ? ' · includes immature cohorts' : ''}';
  }
  return metric.usesDeliveries
      ? '${slice.deliveries.length} delivery records'
      : '${slice.overview.totalLeads} leads in cohort';
}

bool _supportsRank(PerformanceSlice slice, ComparisonMetric metric) {
  if (metric.isRate) return (slice.denominator(metric) ?? 0) >= 10;
  if (metric == ComparisonMetric.deliveryDays) {
    return slice.deliveries.length >= 8;
  }
  return true;
}

String _supportLabel(PerformanceSlice slice, ComparisonMetric metric) {
  final sample = sampleLabel(slice, metric);
  if (_supportsRank(slice, metric)) return sample;
  final threshold = metric == ComparisonMetric.deliveryDays
      ? '8 delivery records'
      : '10 eligible leads';
  return '$sample · insufficient support for an extreme badge (minimum $threshold)';
}

String _rankingExplanation(ComparisonMetric metric, bool meaningfulExtremes) {
  final direction = switch (metric.highTone) {
    ComparisonRankTone.positive =>
      'Higher values are treated as favourable for this measure; the lowest supported result is marked for investigation, not labelled a failure.',
    ComparisonRankTone.attention =>
      'Higher values indicate more recorded exposure or delay; the highest supported result is marked for investigation and is never labelled “best”.',
    ComparisonRankTone.neutral =>
      'The extremes describe concentration or volume and are neutral rather than a performance verdict.',
  };
  final support = metric.isRate
      ? 'Extreme badges require at least 10 eligible leads.'
      : metric == ComparisonMetric.deliveryDays
          ? 'Extreme badges require at least 8 delivery records.'
          : 'Counts and values retain their displayed record support.';
  final extremes = meaningfulExtremes
      ? 'Ties share a rank and use an explicit tied label.'
      : 'No extreme badge is shown because fewer than two supported, unequal results are available.';
  return '#1 is the highest recorded ${metric.label.toLowerCase()}. $direction $support $extremes';
}

String _extremeLabel(ComparisonMetric metric,
    {required bool high, required bool tied}) {
  final label = switch ((metric, high)) {
    (ComparisonMetric.deliveries, true) => 'Most deliveries',
    (ComparisonMetric.deliveries, false) => 'Fewest deliveries',
    (ComparisonMetric.deliveredValue, true) => 'Highest delivered deal value',
    (ComparisonMetric.deliveredValue, false) => 'Lowest delivered deal value',
    (ComparisonMetric.leads, true) => 'Highest lead demand',
    (ComparisonMetric.leads, false) => 'Lowest lead demand',
    (ComparisonMetric.conversion, true) => 'Highest resolved conversion',
    (ComparisonMetric.conversion, false) => 'Lowest resolved conversion',
    (ComparisonMetric.activeCount, true) => 'Most active opportunities',
    (ComparisonMetric.activeCount, false) => 'Fewest active opportunities',
    (ComparisonMetric.activeValue, true) => 'Highest active opportunity value',
    (ComparisonMetric.activeValue, false) => 'Lowest active opportunity value',
    (ComparisonMetric.staleCount, true) => 'Most stale opportunities',
    (ComparisonMetric.staleCount, false) => 'Fewest stale opportunities',
    (ComparisonMetric.staleValue, true) => 'Highest stale opportunity value',
    (ComparisonMetric.staleValue, false) => 'Lowest stale opportunity value',
    (ComparisonMetric.overdueCount, true) => 'Most overdue expected closes',
    (ComparisonMetric.overdueCount, false) => 'Fewest overdue expected closes',
    (ComparisonMetric.lostCount, true) => 'Most recorded losses',
    (ComparisonMetric.lostCount, false) => 'Fewest recorded losses',
    (ComparisonMetric.lostValue, true) => 'Highest lost deal value',
    (ComparisonMetric.lostValue, false) => 'Lowest lost deal value',
    (ComparisonMetric.averageValue, true) => 'Highest average deal value',
    (ComparisonMetric.averageValue, false) => 'Lowest average deal value',
    (ComparisonMetric.medianValue, true) => 'Highest median deal value',
    (ComparisonMetric.medianValue, false) => 'Lowest median deal value',
    (ComparisonMetric.contactRate, true) => 'Highest contact rate',
    (ComparisonMetric.contactRate, false) => 'Lowest contact rate',
    (ComparisonMetric.testDriveRate, true) =>
      'Highest post-contact test-drive rate',
    (ComparisonMetric.testDriveRate, false) =>
      'Lowest post-contact test-drive rate',
    (ComparisonMetric.closeRate, true) => 'Highest order progression',
    (ComparisonMetric.closeRate, false) => 'Lowest order progression',
    (ComparisonMetric.deliveryDays, true) => 'Longest median delivery time',
    (ComparisonMetric.deliveryDays, false) => 'Shortest median delivery time',
  };
  return tied ? 'Tied · $label' : label;
}
