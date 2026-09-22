import '../../analytics/models/analytical_lead.dart';
import '../../analytics/models/analytics_results.dart';
import '../../application/analysis/analysis_controller.dart';
import '../../application/analysis/analysis_results.dart';
import '../../insights/models/management_insight.dart';
import '../dashboard/dashboard_view_data.dart';

final class ComparisonRow {
  const ComparisonRow({
    required this.label,
    this.id,
    required this.scoped,
    required this.benchmark,
  });

  final String label;
  final String? id;
  final String scoped;
  final String benchmark;
}

final class InvestigationViewData {
  const InvestigationViewData({
    required this.title,
    required this.subtitle,
    required this.kpis,
    required this.funnel,
    required this.sources,
    required this.vehicles,
    required this.reps,
    required this.lostReasons,
    required this.pipeline,
    required this.delivery,
    required this.insights,
    required this.staleLeadIds,
    required this.overdueLeadIds,
  });

  final String title;
  final String subtitle;
  final List<ComparisonRow> kpis;
  final List<ComparisonRow> funnel;
  final List<ComparisonRow> sources;
  final List<ComparisonRow> vehicles;
  final List<ComparisonRow> reps;
  final List<ComparisonRow> lostReasons;
  final List<ComparisonRow> pipeline;
  final List<ComparisonRow> delivery;
  final List<ManagementInsight> insights;
  final List<String> staleLeadIds;
  final List<String> overdueLeadIds;
}

final class InvestigationPresenter {
  const InvestigationPresenter();

  InvestigationViewData branch({
    required AnalysisController scoped,
    required AnalysisController network,
  }) {
    final branch = scoped.dataset.branches
        .where((item) => item.id == scoped.filters.branchId)
        .first;
    final local = scoped.results;
    final all = network.results;
    final stale = local.pipeline
        .where((item) =>
            item.ageingBand == PipelineAgeingBand.stale ||
            item.ageingBand == PipelineAgeingBand.severelyStale)
        .map((item) => item.leadId)
        .toList(growable: false);
    final overdue = local.pipeline
        .where((item) => item.isOverdueOrderStage)
        .map((item) => item.leadId)
        .toList(growable: false);
    final branchInsightIds = {
      ...local.insights.map((item) => item.id),
    };
    final insights = <ManagementInsight>[
      ...all.insights
          .where((item) => item.dimensions.branchIds.contains(branch.id)),
      ...local.insights.where((item) =>
          !branchInsightIds.contains(item.id) ||
          !all.insights.any((other) => other.id == item.id)),
    ];

    return InvestigationViewData(
      title: branch.name,
      subtitle: '${branch.city} · Performance compared with all branches',
      kpis: [
        _row('Lead volume', local.overview.totalLeads, all.overview.totalLeads),
        _row(
            'Delivered / lost / active',
            '${local.overview.delivered} / ${local.overview.lost} / ${local.overview.activeLeads}',
            '${all.overview.delivered} / ${all.overview.lost} / ${all.overview.activeLeads}'),
        _rateRow('Resolved conversion', local.overview.resolvedConversion,
            all.overview.resolvedConversion),
        _valueRow(
            'Active opportunity value',
            local.overview.activeOpportunityValue,
            all.overview.activeOpportunityValue),
        _valueRow('Delivered deal value', local.overview.deliveredDealValue,
            all.overview.deliveredDealValue),
      ],
      funnel: [
        ..._gateRows(local.managementGates, all.managementGates),
        ..._funnelRows(local.funnel, all.funnel),
      ],
      sources: local.sources
          .map((item) => ComparisonRow(
                label: item.source ?? 'Unattributed',
                scoped:
                    '${item.volume} leads · ${_rate(item.contactRate)} contact · ${_rate(item.resolvedConversion)} resolved',
                benchmark: _sourceBenchmark(item.source, all.sources),
              ))
          .toList(growable: false),
      vehicles: local.vehicles
          .map((item) => ComparisonRow(
                label: item.model,
                scoped:
                    '${_rate(item.leadShare)} demand · ${_rate(item.resolvedConversion)} resolved · ${_rate(item.deliveredValueShare)} delivered value',
                benchmark: _vehicleBenchmark(item.model, all.vehicles),
              ))
          .toList(growable: false),
      reps: local.salesReps
          .map((item) => ComparisonRow(
                label: item.repName,
                id: item.repId,
                scoped:
                    '${item.metrics.leadVolume} leads · ${_rate(item.metrics.resolvedConversion)} resolved',
                benchmark:
                    '${item.metrics.active} active · ${DashboardPresenter.formatValue(item.metrics.deliveredDealValue)} delivered value',
              ))
          .toList(growable: false),
      lostReasons: local.lostReasons
          .map((item) => ComparisonRow(
                label: item.reason ?? 'Unspecified',
                scoped:
                    '${item.total.count} leads · ${DashboardPresenter.formatValue(item.total.affectedValue)} affected value',
                benchmark: 'Original source reason',
              ))
          .toList(growable: false),
      pipeline: [
        _row('Active opportunities', local.overview.activeLeads,
            all.overview.activeLeads),
        _row('Stale opportunities', stale.length,
            all.pipeline.where(_isStale).length),
        _row('Overdue order-stage', overdue.length,
            all.pipeline.where((item) => item.isOverdueOrderStage).length),
      ],
      delivery: _deliveryRows(local.deliveries, all.deliveries),
      insights: insights.take(8).toList(growable: false),
      staleLeadIds: stale,
      overdueLeadIds: overdue,
    );
  }

  InvestigationViewData rep({
    required AnalysisController scoped,
    required AnalysisController branch,
  }) {
    final rep = scoped.dataset.salesReps
        .where((item) => item.id == scoped.filters.repId)
        .first;
    final branchName = scoped.dataset.branches
        .where((item) => item.id == rep.branchId)
        .map((item) => item.name)
        .firstOrNull;
    final local = scoped.results;
    final benchmark = branch.results;
    final stale = local.pipeline
        .where(_isStale)
        .map((item) => item.leadId)
        .toList(growable: false);
    final overdue = local.pipeline
        .where((item) => item.isOverdueOrderStage)
        .map((item) => item.leadId)
        .toList(growable: false);
    return InvestigationViewData(
      title: rep.name,
      subtitle: '${branchName ?? rep.branchId} · Coaching and follow-up',
      kpis: [
        _row('Workload', local.overview.totalLeads,
            benchmark.salesReps.isEmpty ? 0 : _averageWorkload(benchmark)),
        _row(
            'Delivered / lost / active',
            '${local.overview.delivered} / ${local.overview.lost} / ${local.overview.activeLeads}',
            '${benchmark.overview.delivered} / ${benchmark.overview.lost} / ${benchmark.overview.activeLeads} branch total'),
        _rateRow('Resolved conversion', local.overview.resolvedConversion,
            benchmark.overview.resolvedConversion),
        _valueRow(
            'Active opportunity value',
            local.overview.activeOpportunityValue,
            benchmark.overview.activeOpportunityValue),
        _valueRow('Delivered deal value', local.overview.deliveredDealValue,
            benchmark.overview.deliveredDealValue),
      ],
      funnel: [
        ..._gateRows(local.managementGates, benchmark.managementGates),
        ..._funnelRows(local.funnel, benchmark.funnel),
      ],
      sources: const [],
      vehicles: const [],
      reps: const [],
      lostReasons: local.lostReasons
          .map((item) => ComparisonRow(
                label: item.reason ?? 'Unspecified',
                scoped: '${item.total.count} leads',
                benchmark:
                    DashboardPresenter.formatValue(item.total.affectedValue),
              ))
          .toList(growable: false),
      pipeline: [
        _row('Active opportunities', local.overview.activeLeads,
            benchmark.overview.activeLeads),
        _row('Stale opportunities', stale.length,
            benchmark.pipeline.where(_isStale).length),
        _row(
            'Overdue order-stage',
            overdue.length,
            benchmark.pipeline
                .where((item) => item.isOverdueOrderStage)
                .length),
      ],
      delivery: _deliveryRows(local.deliveries, benchmark.deliveries),
      insights: [
        ...branch.results.insights
            .where((item) => item.dimensions.repIds.contains(rep.id)),
        ...local.insights
            .where((item) => item.category != InsightCategory.branch),
      ].take(8).toList(growable: false),
      staleLeadIds: stale,
      overdueLeadIds: overdue,
    );
  }

  static bool _isStale(PipelineOpportunity item) =>
      item.ageingBand == PipelineAgeingBand.stale ||
      item.ageingBand == PipelineAgeingBand.severelyStale;

  static List<ComparisonRow> _funnelRows(
      List<FunnelStageResult> scoped, List<FunnelStageResult> benchmark) {
    return scoped.map((item) {
      final peer =
          benchmark.where((value) => value.stage == item.stage).firstOrNull;
      return ComparisonRow(
        label: _stage(item.stage),
        scoped:
            '${item.reachedCount} reached · ${_rate(item.progressionRate)} progress · ${_duration(item.medianTransitionDuration)} median',
        benchmark: peer == null
            ? 'Not enough comparison data'
            : '${_rate(peer.progressionRate)} progress · ${_duration(peer.medianTransitionDuration)} median',
      );
    }).toList(growable: false);
  }

  static List<ComparisonRow> _gateRows(
      List<ManagementGateResult> scoped, List<ManagementGateResult> benchmark) {
    return scoped.map((item) {
      final peer =
          benchmark.where((value) => value.gate == item.gate).firstOrNull;
      return ComparisonRow(
        label: 'Management gate · ${_gate(item.gate)}',
        scoped:
            '${item.reachedCount}/${item.eligibleCount} reached · ${_rate(item.conversion)} conversion · ${item.lostBeforeGateCount} lost before gate',
        benchmark: peer == null
            ? 'Not enough comparison data'
            : '${_rate(peer.conversion)} conversion · ${peer.lostBeforeGateCount} lost before gate',
      );
    }).toList(growable: false);
  }

  static List<ComparisonRow> _deliveryRows(
      DeliveryAnalytics scoped, DeliveryAnalytics benchmark) {
    return [
      _row('Linked deliveries', scoped.overall.count, benchmark.overall.count),
      ComparisonRow(
        label: 'Median delivery duration',
        scoped: _days(scoped.overall.medianDays),
        benchmark: _days(benchmark.overall.medianDays),
      ),
      ComparisonRow(
        label: '90th percentile duration',
        scoped: _days(scoped.overall.p90Days),
        benchmark: _days(benchmark.overall.p90Days),
      ),
      ...scoped.delayReasons.map((item) => ComparisonRow(
            label: 'Delay reason · ${item.reason}',
            scoped:
                '${item.stats.count} deliveries · ${_days(item.stats.medianDays)} median · ${_signedDays(item.incrementalAverageDays)} vs no-delay baseline',
            benchmark: _delayBenchmark(item.reason, benchmark.delayReasons),
          )),
    ];
  }

  static String _delayBenchmark(
      String reason, List<DelayReasonAnalytics> benchmark) {
    final item = benchmark.where((value) => value.reason == reason).firstOrNull;
    return item == null
        ? 'Not enough comparison data'
        : '${item.stats.count} deliveries · ${_days(item.stats.medianDays)} median';
  }

  static ComparisonRow _row(String label, Object scoped, Object benchmark) =>
      ComparisonRow(label: label, scoped: '$scoped', benchmark: '$benchmark');

  static ComparisonRow _rateRow(
          String label, double? scoped, double? benchmark) =>
      ComparisonRow(
          label: label, scoped: _rate(scoped), benchmark: _rate(benchmark));

  static ComparisonRow _valueRow(String label, num scoped, num benchmark) =>
      ComparisonRow(
          label: label,
          scoped: DashboardPresenter.formatValue(scoped),
          benchmark: DashboardPresenter.formatValue(benchmark));

  static String _sourceBenchmark(String? source, List<SourceAnalytics> all) {
    final item = all.where((value) => value.source == source).firstOrNull;
    return item == null
        ? 'No network benchmark'
        : '${item.volume} network leads · ${_rate(item.contactRate)} contact · ${_rate(item.resolvedConversion)} resolved';
  }

  static String _vehicleBenchmark(String model, List<VehicleAnalytics> all) {
    final item = all.where((value) => value.model == model).firstOrNull;
    return item == null
        ? 'No network benchmark'
        : '${_rate(item.leadShare)} network demand · ${_rate(item.resolvedConversion)} resolved';
  }

  static int _averageWorkload(AnalysisResults result) =>
      result.salesReps.isEmpty
          ? 0
          : (result.overview.totalLeads / result.salesReps.length).round();

  static String _rate(double? value) => DashboardPresenter.formatRate(value);
  static String _days(double? value) =>
      value == null ? '—' : '${value.toStringAsFixed(1)} days';
  static String _signedDays(double? value) => value == null
      ? '—'
      : '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)} days';
  static String _duration(Duration? value) =>
      value == null ? '—' : '${(value.inHours / 24.0).toStringAsFixed(1)} days';

  static String _stage(FunnelStage stage) => switch (stage) {
        FunnelStage.newLead => 'New → contacted',
        FunnelStage.contacted => 'Contacted → test drive',
        FunnelStage.testDrive => 'Test drive → negotiation',
        FunnelStage.negotiation => 'Negotiation → order',
        FunnelStage.orderPlaced => 'Order → delivery',
        FunnelStage.delivered => 'Delivered',
      };

  static String _gate(ManagementGate gate) => switch (gate) {
        ManagementGate.contact => 'Contact',
        ManagementGate.testDrive => 'Test drive',
        ManagementGate.close => 'Close',
      };
}
