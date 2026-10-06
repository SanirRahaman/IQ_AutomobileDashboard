import 'package:flutter/material.dart';

import '../../analytics/services/performance_explorer.dart';
import '../../insights/models/management_insight.dart';
import '../dashboard/dashboard_view_data.dart';

/// The shared visual vocabulary for dealership concepts.
///
/// These icons identify what a measure represents. Performance direction and
/// severity remain separate concerns and use their existing typed treatments.
abstract final class DashboardIcons {
  static const leads = Icons.person_add_alt_1_outlined;
  static const delivered = Icons.directions_car_outlined;
  static const activeOpportunity = Icons.work_outline;
  static const opportunityValue = Icons.account_balance_wallet_outlined;
  static const conversion = Icons.percent;
  static const target = Icons.track_changes;
  static const followUp = Icons.playlist_add_check;
  static const branch = Icons.store_outlined;
  static const representative = Icons.groups_outlined;
  static const vehicle = Icons.directions_car_outlined;
  static const source = Icons.campaign_outlined;
  static const trend = Icons.show_chart;
  static const inactivity = Icons.schedule;
  static const overdue = Icons.event_busy_outlined;
  static const dataQuality = Icons.report_problem_outlined;
  static const records = Icons.receipt_long_outlined;
  static const download = Icons.download_outlined;
  static const pipeline = Icons.view_kanban_outlined;
  static const delivery = Icons.local_shipping_outlined;
  static const funnel = Icons.filter_alt_outlined;
  static const loss = Icons.cancel_outlined;
  static const stale = Icons.hourglass_bottom_outlined;
  static const opportunity = Icons.lightbulb_outline;
  static const timing = Icons.timer_outlined;

  static IconData pulse(PulseMetricKind kind) => switch (kind) {
        PulseMetricKind.enquiries => leads,
        PulseMetricKind.delivered => delivered,
        PulseMetricKind.conversion => conversion,
        PulseMetricKind.active => opportunityValue,
        PulseMetricKind.deliveredValue => opportunityValue,
        PulseMetricKind.attention => followUp,
        PulseMetricKind.target => target,
      };

  static IconData insight(InsightCategory category) => switch (category) {
        InsightCategory.funnel => funnel,
        InsightCategory.branch => branch,
        InsightCategory.rep => representative,
        InsightCategory.source => source,
        InsightCategory.vehicle => vehicle,
        InsightCategory.pipeline => pipeline,
        InsightCategory.delivery => delivery,
        InsightCategory.dataQuality => dataQuality,
        InsightCategory.positiveOpportunity => opportunity,
      };

  static IconData dimension(ComparisonDimension dimension) =>
      switch (dimension) {
        ComparisonDimension.model => vehicle,
        ComparisonDimension.branch => branch,
        ComparisonDimension.representative => representative,
        ComparisonDimension.source => source,
      };

  static IconData metric(ComparisonMetric metric) => switch (metric) {
        ComparisonMetric.deliveries => delivered,
        ComparisonMetric.deliveredValue => opportunityValue,
        ComparisonMetric.leads => leads,
        ComparisonMetric.conversion ||
        ComparisonMetric.contactRate ||
        ComparisonMetric.testDriveRate ||
        ComparisonMetric.closeRate =>
          conversion,
        ComparisonMetric.activeCount => activeOpportunity,
        ComparisonMetric.activeValue ||
        ComparisonMetric.averageValue ||
        ComparisonMetric.medianValue =>
          opportunityValue,
        ComparisonMetric.staleCount || ComparisonMetric.staleValue => stale,
        ComparisonMetric.overdueCount => overdue,
        ComparisonMetric.lostCount || ComparisonMetric.lostValue => loss,
        ComparisonMetric.deliveryDays => timing,
      };
}

class ConceptIcon extends StatelessWidget {
  const ConceptIcon({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.color,
    this.backgroundColor,
    this.size = 17,
    this.boxSize = 28,
  });

  final IconData icon;
  final String semanticLabel;
  final Color? color;
  final Color? backgroundColor;
  final double size;
  final double boxSize;

  @override
  Widget build(BuildContext context) => Semantics(
        label: semanticLabel,
        image: true,
        child: Container(
          width: boxSize,
          height: boxSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(7),
          ),
          child: ExcludeSemantics(
            child: Icon(icon, size: size, color: color),
          ),
        ),
      );
}

class IconHeading extends StatelessWidget {
  const IconHeading({
    super.key,
    required this.icon,
    required this.label,
    required this.style,
    this.color,
    this.iconSize = 19,
  });

  final IconData icon;
  final String label;
  final TextStyle? style;
  final Color? color;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: style)),
        ],
      );
}
