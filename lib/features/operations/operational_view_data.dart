import '../../analytics/models/analytical_lead.dart';
import '../../analytics/models/analytics_results.dart';
import '../../application/analysis/analysis_controller.dart';
import '../../data/models/dealership_models.dart';
import '../dashboard/dashboard_view_data.dart';

final class OperationalRow {
  const OperationalRow({
    required this.label,
    required this.primary,
    required this.secondary,
    required this.leadIds,
  });

  final String label;
  final String primary;
  final String secondary;
  final List<String> leadIds;
}

final class PipelineViewData {
  const PipelineViewData({
    required this.activeCount,
    required this.activeValue,
    required this.staleValue,
    required this.thresholdDescription,
    required this.byStage,
    required this.inactivity,
    required this.age,
    required this.slippage,
    required this.backlog,
    required this.oldest,
    required this.branches,
    required this.reps,
  });

  final String activeCount;
  final String activeValue;
  final String staleValue;
  final String thresholdDescription;
  final List<OperationalRow> byStage;
  final List<OperationalRow> inactivity;
  final List<OperationalRow> age;
  final OperationalRow slippage;
  final OperationalRow backlog;
  final List<OperationalRow> oldest;
  final List<OperationalRow> branches;
  final List<OperationalRow> reps;
}

final class DeliveryViewData {
  const DeliveryViewData({
    required this.count,
    required this.median,
    required this.average,
    required this.distribution,
    required this.branches,
    required this.vehicles,
    required this.delayReasons,
    required this.expectedClose,
  });

  final String count;
  final String median;
  final String average;
  final List<OperationalRow> distribution;
  final List<OperationalRow> branches;
  final List<OperationalRow> vehicles;
  final List<OperationalRow> delayReasons;
  final List<OperationalRow> expectedClose;
}

final class OperationalPresenter {
  const OperationalPresenter();

  PipelineViewData pipeline(AnalysisController controller) {
    final data = controller.results.pipelineOperations;
    final branches = {
      for (final item in controller.dataset.branches) item.id: item.name,
    };
    final reps = {
      for (final item in controller.dataset.salesReps) item.id: item.name,
    };
    return PipelineViewData(
      activeCount: '${data.activeCount}',
      activeValue: DashboardPresenter.formatValue(data.activeValue),
      staleValue: DashboardPresenter.formatValue(data.staleValue),
      thresholdDescription:
          'Healthy: <${data.thresholds.ageingAfterDays} days · Watch: ${data.thresholds.ageingAfterDays}–${data.thresholds.staleAfterDays - 1} · Stale: ${data.thresholds.staleAfterDays}–${data.thresholds.severelyStaleAfterDays - 1} · Critical: ${data.thresholds.severelyStaleAfterDays}+ days',
      byStage: _bucketRows(data.byStage, _stage),
      inactivity: _bucketRows(data.byInactivity, _band),
      age: _bucketRows(data.byAge, _band),
      slippage: _row('Expected close overdue', data.overdueExpectedClose,
          'Active records past their expected-close date'),
      backlog: _row('Order-stage backlog', data.orderStageBacklog,
          'Active records currently at order placed'),
      oldest: data.oldest
          .map((item) => OperationalRow(
                label: item.leadId,
                primary:
                    '${item.ageDays} days old · ${item.inactivityDays} days inactive',
                secondary:
                    '${_stage(item.stage)} · ${DashboardPresenter.formatValue(item.dealValue)}',
                leadIds: [item.leadId],
              ))
          .toList(growable: false),
      branches: data.byBranch.entries
          .map((entry) => _row(branches[entry.key] ?? entry.key, entry.value,
              'Active opportunities'))
          .toList(growable: false),
      reps: data.byRep.entries
          .map((entry) => _row(reps[entry.key] ?? entry.key, entry.value,
              'Active opportunities'))
          .toList(growable: false),
    );
  }

  DeliveryViewData delivery(AnalysisController controller) {
    final data = controller.results.deliveries;
    final deliveries = controller.results.deliveryScope.source.deliveries;
    final leads = {
      for (final item in controller.results.deliveryScope.leads) item.id: item,
    };
    final scopedDeliveries = deliveries
        .where((item) => leads.containsKey(item.leadId))
        .toList(growable: false);
    List<String> idsWhere(bool Function(Delivery delivery) test) =>
        scopedDeliveries.where(test).map((item) => item.leadId).toList();

    return DeliveryViewData(
      count: '${data.overall.count}',
      median: _days(data.overall.medianDays),
      average: _days(data.overall.averageDays),
      distribution: [
        OperationalRow(
            label: 'Median',
            primary: _days(data.overall.medianDays),
            secondary: '50th percentile',
            leadIds: idsWhere((_) => true)),
        OperationalRow(
            label: '80th percentile',
            primary: _days(data.overall.p80Days),
            secondary: 'Observed delivery-duration distribution',
            leadIds: idsWhere((_) => true)),
        OperationalRow(
            label: '90th percentile',
            primary: _days(data.overall.p90Days),
            secondary: 'Observed delivery-duration distribution',
            leadIds: idsWhere((_) => true)),
      ],
      branches: data.byBranch.entries.map((entry) {
        final name = controller.dataset.branches
            .where((item) => item.id == entry.key)
            .map((item) => item.name)
            .firstOrNull;
        return _deliveryStatsRow(
          name ?? entry.key,
          entry.value,
          idsWhere((delivery) => leads[delivery.leadId]?.branchId == entry.key),
        );
      }).toList(growable: false),
      vehicles: data.byVehicle.entries
          .map((entry) => _deliveryStatsRow(
                entry.key,
                entry.value,
                idsWhere((delivery) =>
                    leads[delivery.leadId]?.vehicleModel == entry.key),
              ))
          .toList(growable: false),
      delayReasons: data.delayReasons.map((item) {
        final incremental = item.incrementalAverageDays;
        final association = incremental == null
            ? 'No no-delay baseline available'
            : '${incremental >= 0 ? '+' : ''}${incremental.toStringAsFixed(1)} days versus deliveries without a recorded delay';
        return OperationalRow(
          label: item.reason,
          primary:
              '${item.stats.count} deliveries · ${_days(item.stats.medianDays)} median',
          secondary: association,
          leadIds: idsWhere((delivery) => delivery.delayReason == item.reason),
        );
      }).toList(growable: false),
      expectedClose: [
        OperationalRow(
          label: 'Delivered by expected close',
          primary:
              '${data.deliveredByExpectedCloseCount}/${data.expectedCloseLinkedCount}',
          secondary: data.expectedCloseLinkedCount == 0
              ? 'No linked expected-close comparisons'
              : DashboardPresenter.formatRate(
                  data.deliveredByExpectedCloseCount /
                      data.expectedCloseLinkedCount),
          leadIds: idsWhere((delivery) => !delivery.deliveryDate
              .isAfter(leads[delivery.leadId]!.lead.expectedCloseDate)),
        ),
        OperationalRow(
          label: 'Delivered after expected close',
          primary:
              '${data.expectedCloseLinkedCount - data.deliveredByExpectedCloseCount}',
          secondary: 'Recorded association; not a causal attribution',
          leadIds: idsWhere((delivery) => delivery.deliveryDate
              .isAfter(leads[delivery.leadId]!.lead.expectedCloseDate)),
        ),
      ],
    );
  }

  static List<OperationalRow> _bucketRows<K>(
          Map<K, PipelineBucket> buckets, String Function(K) label) =>
      buckets.entries
          .map((entry) => _row(label(entry.key), entry.value,
              'Active opportunity count and value'))
          .toList(growable: false);

  static OperationalRow _row(
          String label, PipelineBucket bucket, String secondary) =>
      OperationalRow(
        label: label,
        primary:
            '${bucket.count} · ${DashboardPresenter.formatValue(bucket.value)}',
        secondary: secondary,
        leadIds: bucket.leadIds,
      );

  static OperationalRow _deliveryStatsRow(
          String label, DeliveryStats stats, List<String> ids) =>
      OperationalRow(
        label: label,
        primary:
            '${stats.count} deliveries · ${_days(stats.medianDays)} median',
        secondary:
            '${_days(stats.averageDays)} average · ${_days(stats.p90Days)} p90',
        leadIds: ids,
      );

  static String _days(double? value) =>
      value == null ? '—' : '${value.toStringAsFixed(1)} days';

  static String _stage(FunnelStage? value) => switch (value) {
        FunnelStage.newLead => 'New',
        FunnelStage.contacted => 'Contacted',
        FunnelStage.testDrive => 'Test drive',
        FunnelStage.negotiation => 'Negotiation',
        FunnelStage.orderPlaced => 'Order placed',
        FunnelStage.delivered => 'Delivered',
        null => 'Unknown stage',
      };

  static String _band(PipelineAgeingBand value) => switch (value) {
        PipelineAgeingBand.recentlyActive => 'Healthy',
        PipelineAgeingBand.ageing => 'Watch',
        PipelineAgeingBand.stale => 'Stale',
        PipelineAgeingBand.severelyStale => 'Critical',
      };
}
