import '../../analytics/models/analytical_lead.dart';
import '../../analytics/models/analytics_results.dart';
import '../../application/analysis/analysis_controller.dart';
import '../../insights/models/management_insight.dart';

enum PulseMetricKind {
  enquiries,
  delivered,
  conversion,
  active,
  deliveredValue,
  attention,
  target,
}

final class PulseMetricViewData {
  const PulseMetricViewData({
    required this.kind,
    required this.label,
    required this.value,
    required this.helper,
  });

  final PulseMetricKind kind;
  final String label;
  final String value;
  final String helper;
}

final class JourneyStageViewData {
  const JourneyStageViewData({
    required this.stage,
    required this.label,
    required this.count,
    required this.progression,
    required this.leakage,
    required this.leakedLeadIds,
  });

  final FunnelStage stage;
  final String label;
  final int count;
  final String progression;
  final String leakage;
  final List<String> leakedLeadIds;
}

final class BranchDiagnosticViewData {
  const BranchDiagnosticViewData({
    required this.id,
    required this.name,
    required this.leadVolume,
    required this.outcomes,
    required this.conversion,
    required this.activeValue,
    required this.bottleneck,
  });

  final String id;
  final String name;
  final String leadVolume;
  final String outcomes;
  final String conversion;
  final String activeValue;
  final String bottleneck;
}

final class SourceDiagnosticViewData {
  const SourceDiagnosticViewData({
    required this.id,
    required this.name,
    required this.volume,
    required this.contactRate,
    required this.resolvedConversion,
    required this.postContactRate,
  });

  final String? id;
  final String name;
  final String volume;
  final String contactRate;
  final String resolvedConversion;
  final String postContactRate;
}

final class VehicleDiagnosticViewData {
  const VehicleDiagnosticViewData({
    required this.id,
    required this.name,
    required this.demandShare,
    required this.conversion,
    required this.deliveredValueShare,
    required this.deliveredValue,
  });

  final String id;
  final String name;
  final String demandShare;
  final String conversion;
  final String deliveredValueShare;
  final String deliveredValue;
}

final class CohortViewData {
  const CohortViewData({
    required this.month,
    required this.volume,
    required this.delivered,
    required this.lost,
    required this.active,
    required this.conversion,
    required this.isMature,
  });

  final String month;
  final int volume;
  final int delivered;
  final int lost;
  final int active;
  final String conversion;
  final bool isMature;
}

final class OperationsViewData {
  const OperationsViewData({
    required this.activeCount,
    required this.activeValue,
    required this.staleCount,
    required this.overdueOrderCount,
    required this.deliveryCount,
    required this.medianDeliveryDays,
    required this.p90DeliveryDays,
  });

  final String activeCount;
  final String activeValue;
  final String staleCount;
  final String overdueOrderCount;
  final String deliveryCount;
  final String medianDeliveryDays;
  final String p90DeliveryDays;
}

final class DashboardViewData {
  const DashboardViewData({
    required this.dateLabel,
    required this.scopeLabel,
    required this.pulse,
    required this.insights,
    required this.journey,
    required this.branches,
    required this.sources,
    required this.vehicles,
    required this.cohorts,
    required this.operations,
    required this.hasResults,
  });

  final String dateLabel;
  final String scopeLabel;
  final List<PulseMetricViewData> pulse;
  final List<ManagementInsight> insights;
  final List<JourneyStageViewData> journey;
  final List<BranchDiagnosticViewData> branches;
  final List<SourceDiagnosticViewData> sources;
  final List<VehicleDiagnosticViewData> vehicles;
  final List<CohortViewData> cohorts;
  final OperationsViewData operations;
  final bool hasResults;
}

final class DashboardPresenter {
  const DashboardPresenter();

  DashboardViewData present(AnalysisController controller) {
    final results = controller.results;
    final overview = results.overview;
    final attentionIds = results.pipeline
        .where((item) =>
            item.isOverdueOrderStage ||
            item.ageingBand == PipelineAgeingBand.stale ||
            item.ageingBand == PipelineAgeingBand.severelyStale)
        .map((item) => item.leadId)
        .toSet();
    final branchName = controller.dataset.branches
        .where((branch) => branch.id == controller.filters.branchId)
        .map((branch) => branch.name)
        .firstOrNull;
    final repName = controller.dataset.salesReps
        .where((rep) => rep.id == controller.filters.repId)
        .map((rep) => rep.name)
        .firstOrNull;

    return DashboardViewData(
      dateLabel:
          '${formatDate(results.performance.start)} – ${formatDate(results.performance.end)}',
      scopeLabel: repName ?? branchName ?? 'Network overview',
      pulse: [
        PulseMetricViewData(
          kind: PulseMetricKind.enquiries,
          label: 'Leads received',
          value: formatInteger(overview.totalLeads),
          helper: 'Leads created inside the selected period and filters.',
        ),
        PulseMetricViewData(
          kind: PulseMetricKind.delivered,
          label: 'Vehicles delivered',
          value: formatInteger(results.performance.deliveredCount),
          helper:
              'Delivery records dated within the selected period, regardless of when the lead arrived.',
        ),
        PulseMetricViewData(
          kind: PulseMetricKind.conversion,
          label: 'Resolved conversion',
          value: formatRate(overview.resolvedConversion),
          helper:
              'Delivered / (delivered + lost), for leads received in this period. Active leads are excluded. Recent groups may still be progressing; see Conversion by lead month.',
        ),
        PulseMetricViewData(
          kind: PulseMetricKind.active,
          label: 'Active opportunities',
          value: formatInteger(overview.activeLeads),
          helper:
              'Open leads received in the selected period, still active as of ${formatDate(results.performance.snapshot)}. Neither delivered nor lost.',
        ),
        PulseMetricViewData(
          kind: PulseMetricKind.target,
          label: 'Target attainment',
          value: formatRate(results.performance.total?.attainment),
          helper: results.performance.unavailableReason ??
              '${results.performance.total?.actual} delivered / ${results.performance.total?.target} supplied unit target. ${results.performance.total?.status}. Delivery dates, matched branch-months only.',
        ),
        PulseMetricViewData(
          kind: PulseMetricKind.attention,
          label: 'Needs follow-up',
          value: formatInteger(attentionIds.length),
          helper:
              'Unique active records that are stale or overdue at order stage.',
        ),
      ],
      insights: results.insights,
      journey: results.funnel.map((stage) {
        final leaked = results.leadScope.leads
            .where((lead) => lead.isLost && lead.lostFromStage == stage.stage)
            .map((lead) => lead.id)
            .toList(growable: false);
        return JourneyStageViewData(
          stage: stage.stage,
          label: _stage(stage.stage),
          count: stage.reachedCount,
          progression: stage.progressionRate == null
              ? 'Completed stage'
              : '${formatRate(stage.progressionRate)} progress',
          leakage: stage.leakageCount == 0
              ? 'No recorded losses at this stage'
              : '${stage.leakageCount} lost · ${formatRate(stage.leakageRate)}',
          leakedLeadIds: leaked,
        );
      }).toList(growable: false),
      branches: results.branches.map((branch) {
        final supported = branch.metrics.funnel
            .where((stage) => stage.progressionRate != null)
            .toList();
        final bottleneck = supported.isEmpty
            ? null
            : supported.reduce((left, right) =>
                left.progressionRate! <= right.progressionRate! ? left : right);
        return BranchDiagnosticViewData(
          id: branch.branchId,
          name: branch.branchName,
          leadVolume: formatInteger(branch.metrics.leadVolume),
          outcomes:
              '${branch.metrics.delivered} delivered · ${branch.metrics.lost} lost',
          conversion: formatRate(branch.metrics.resolvedConversion),
          activeValue: formatValue(branch.metrics.activeOpportunityValue),
          bottleneck: bottleneck == null
              ? 'Not enough stage history'
              : '${_stage(bottleneck.stage)} → ${formatRate(bottleneck.progressionRate)}',
        );
      }).toList(growable: false),
      sources: (results.sources.toList()
            ..sort((left, right) => right.volume.compareTo(left.volume)))
          .map((source) => SourceDiagnosticViewData(
                id: source.source,
                name: source.source == null
                    ? 'Unattributed'
                    : _humanize(source.source!),
                volume: formatInteger(source.volume),
                contactRate: formatRate(source.contactRate),
                resolvedConversion: formatRate(source.resolvedConversion),
                postContactRate: formatRate(source.testDriveAmongContacted),
              ))
          .toList(growable: false),
      vehicles: (results.vehicles.toList()
            ..sort((left, right) =>
                right.deliveredValue.compareTo(left.deliveredValue)))
          .map((vehicle) => VehicleDiagnosticViewData(
                id: vehicle.model,
                name: vehicle.model,
                demandShare: formatRate(vehicle.leadShare),
                conversion: formatRate(vehicle.resolvedConversion),
                deliveredValueShare: formatRate(vehicle.deliveredValueShare),
                deliveredValue: formatValue(vehicle.deliveredValue),
              ))
          .toList(growable: false),
      cohorts: results.cohorts
          .map((cohort) => CohortViewData(
                month: formatMonth(cohort.month),
                volume: cohort.leadVolume,
                delivered: cohort.delivered,
                lost: cohort.lost,
                active: cohort.active,
                conversion: formatRate(cohort.resolvedConversion),
                isMature: cohort.isMature,
              ))
          .toList(growable: false),
      operations: OperationsViewData(
        activeCount: formatInteger(overview.activeLeads),
        activeValue: formatValue(overview.activeOpportunityValue),
        staleCount: formatInteger(results.pipeline
            .where((item) =>
                item.ageingBand == PipelineAgeingBand.stale ||
                item.ageingBand == PipelineAgeingBand.severelyStale)
            .length),
        overdueOrderCount: formatInteger(
            results.pipeline.where((item) => item.isOverdueOrderStage).length),
        deliveryCount: formatInteger(results.deliveries.overall.count),
        medianDeliveryDays: _days(results.deliveries.overall.medianDays),
        p90DeliveryDays: _days(results.deliveries.overall.p90Days),
      ),
      hasResults:
          overview.totalLeads > 0 || results.performance.deliveredCount > 0,
    );
  }

  static String formatInteger(num value) {
    final integer = value.round().toString();
    return integer.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
  }

  static String formatRate(double? value) =>
      value == null ? '—' : '${(value * 100).toStringAsFixed(1)}%';

  static String formatValue(num value) {
    final absolute = value.abs().toDouble();
    if (absolute >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(2)}B value';
    }
    if (absolute >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(2)}M value';
    }
    if (absolute >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K value';
    }
    return '${formatInteger(value)} value';
  }

  static String _days(double? value) =>
      value == null ? '—' : '${value.toStringAsFixed(1)} days';

  static String formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')} '
      '${_monthName(value.month)} ${value.year}';

  static String formatMonth(DateTime value) =>
      '${_monthName(value.month)} ${value.year}';

  static String _monthName(int month) => const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ][month - 1];

  static String _stage(FunnelStage stage) => switch (stage) {
        FunnelStage.newLead => 'New',
        FunnelStage.contacted => 'Contacted',
        FunnelStage.testDrive => 'Test drive',
        FunnelStage.negotiation => 'Negotiation',
        FunnelStage.orderPlaced => 'Order placed',
        FunnelStage.delivered => 'Delivered',
      };

  static String _humanize(String value) => value
      .split('_')
      .map((word) => word.isEmpty
          ? word
          : '${word.substring(0, 1).toUpperCase()}${word.substring(1)}')
      .join(' ');
}
