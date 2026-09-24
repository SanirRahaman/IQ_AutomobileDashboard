import '../../analytics/services/performance_explorer.dart';
import '../dashboard/dashboard_view_data.dart';

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
