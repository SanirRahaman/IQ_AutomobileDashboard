import '../../data/models/dealership_models.dart';
import '../models/analytical_lead.dart';
import '../models/analytics_results.dart';

final class DealershipAnalyticsEngine {
  const DealershipAnalyticsEngine(
    this.dataset, {
    this.ageingConfig = const PipelineAgeingConfig(),
  });

  final AnalyticalDataset dataset;
  final PipelineAgeingConfig ageingConfig;

  BusinessOverview businessOverview([Iterable<AnalyticalLead>? scope]) {
    final leads = _list(scope);
    final active = leads.where((lead) => lead.isActive).toList();
    final delivered = leads.where((lead) => lead.isDelivered).toList();
    final lost = leads.where((lead) => lead.isLost).toList();
    final resolvedCount = delivered.length + lost.length;
    return BusinessOverview(
      totalLeads: leads.length,
      activeLeads: active.length,
      resolvedLeads: resolvedCount,
      delivered: delivered.length,
      lost: lost.length,
      resolvedConversion: _rate(delivered.length, resolvedCount),
      activeOpportunityValue: _sumValue(active),
      deliveredDealValue: _sumValue(delivered),
      dealValue: _valueProfile(leads),
    );
  }

  List<FunnelStageResult> funnel([Iterable<AnalyticalLead>? scope]) {
    final leads = _list(scope);
    return FunnelStage.values.map((stage) {
      final reached = leads.where((lead) => _reached(lead, stage)).toList();
      final next = _nextStage(stage);
      final progressed = next == null
          ? const <AnalyticalLead>[]
          : reached.where((lead) => _reached(lead, next)).toList();
      final leaked = reached
          .where((lead) => lead.isLost && lead.lostFromStage == stage)
          .toList();
      final durations = next == null
          ? const <Duration>[]
          : reached
              .map((lead) => _transitionDuration(lead, stage))
              .whereType<Duration>()
              .toList();
      return FunnelStageResult(
        stage: stage,
        reachedCount: reached.length,
        progressionCount: progressed.length,
        progressionRate:
            next == null ? null : _rate(progressed.length, reached.length),
        leakageCount: leaked.length,
        leakageRate: _rate(leaked.length, reached.length),
        averageTransitionDuration: _averageDuration(durations),
        medianTransitionDuration: _medianDuration(durations),
      );
    }).toList(growable: false);
  }

  List<ManagementGateResult> managementGates(
      [Iterable<AnalyticalLead>? scope]) {
    final leads = _list(scope);
    final contacted = leads.where((lead) => lead.reachedContacted).toList();
    final testDriven = leads.where((lead) => lead.reachedTestDrive).toList();
    final closed = leads.where((lead) => lead.reachedOrderPlaced).toList();
    return [
      _gate(
        ManagementGate.contact,
        leads,
        contacted,
        leads.where(
            (lead) => lead.isLost && lead.lostFromStage == FunnelStage.newLead),
      ),
      _gate(
        ManagementGate.testDrive,
        contacted,
        testDriven,
        leads.where((lead) =>
            lead.isLost && lead.lostFromStage == FunnelStage.contacted),
      ),
      _gate(
        ManagementGate.close,
        testDriven,
        closed,
        leads.where((lead) =>
            lead.isLost &&
            (lead.lostFromStage == FunnelStage.testDrive ||
                lead.lostFromStage == FunnelStage.negotiation)),
      ),
    ];
  }

  List<BranchAnalytics> branches([Iterable<AnalyticalLead>? scope]) {
    final leads = _list(scope);
    final deliveryByLead = {
      for (final delivery in dataset.source.deliveries)
        delivery.leadId: delivery,
    };
    return dataset.source.branches.map((branch) {
      final group = leads.where((lead) => lead.branchId == branch.id).toList();
      final salesOfficers = dataset.source.salesReps.where((rep) =>
          rep.branchId == branch.id &&
          rep.role.value == SalesRepRole.salesOfficer);
      final deliveries = group
          .map((lead) => deliveryByLead[lead.id])
          .whereType<Delivery>()
          .toList();
      return BranchAnalytics(
        branchId: branch.id,
        branchName: branch.name,
        metrics: _segment(group),
        workloadPerSalesOfficer: _ratio(group.length, salesOfficers.length),
        lostReasons: _reasonCounts(group),
        pipelineAgeing: _pipelineSummary(group),
        deliveryPerformance: _deliveryStats(deliveries),
      );
    }).toList(growable: false);
  }

  List<SalesRepAnalytics> salesReps([Iterable<AnalyticalLead>? scope]) {
    final leads = _list(scope);
    final branchNames = {
      for (final branch in dataset.source.branches) branch.id: branch.name,
    };
    return dataset.source.salesReps.map((rep) {
      final group = leads.where((lead) => lead.repId == rep.id).toList();
      return SalesRepAnalytics(
        repId: rep.id,
        repName: rep.name,
        branchId: rep.branchId,
        branchName: branchNames[rep.branchId],
        metrics: _segment(group),
      );
    }).toList(growable: false);
  }

  List<SourceAnalytics> sources([Iterable<AnalyticalLead>? scope]) {
    final leads = _list(scope);
    final grouped =
        _groupBy<AnalyticalLead, String?>(leads, (lead) => lead.source);
    return grouped.entries.map((entry) {
      final group = entry.value;
      final contacted = group.where((lead) => lead.reachedContacted).toList();
      final testDriven = group.where((lead) => lead.reachedTestDrive).toList();
      final delivered = group.where((lead) => lead.isDelivered).toList();
      final lost = group.where((lead) => lead.isLost).toList();
      return SourceAnalytics(
        source: entry.key,
        volume: group.length,
        contactRate: _rate(contacted.length, group.length),
        testDriveRate: _rate(testDriven.length, group.length),
        rawDeliveredRate: _rate(delivered.length, group.length),
        resolvedConversion:
            _rate(delivered.length, delivered.length + lost.length),
        deliveredAmongContacted: _rate(delivered.length, contacted.length),
        testDriveAmongContacted: _rate(testDriven.length, contacted.length),
        activeValue: _sumValue(group.where((lead) => lead.isActive)),
        deliveredValue: _sumValue(delivered),
      );
    }).toList(growable: false);
  }

  List<VehicleAnalytics> vehicles([Iterable<AnalyticalLead>? scope]) {
    final leads = _list(scope);
    final grouped =
        _groupBy<AnalyticalLead, String>(leads, (lead) => lead.vehicleModel);
    final allDelivered = leads.where((lead) => lead.isDelivered).toList();
    final totalDeliveredValue = _sumValue(allDelivered).toDouble();
    return grouped.entries.map((entry) {
      final group = entry.value;
      final delivered = group.where((lead) => lead.isDelivered).toList();
      final lost = group.where((lead) => lead.isLost).toList();
      final leadShare = _rate(group.length, leads.length);
      final deliveredValue = _sumValue(delivered);
      final deliveredValueShare = totalDeliveredValue == 0
          ? null
          : deliveredValue.toDouble() / totalDeliveredValue;
      return VehicleAnalytics(
        model: entry.key,
        leadCount: group.length,
        leadShare: leadShare,
        deliveredCount: delivered.length,
        deliveredShare: _rate(delivered.length, allDelivered.length),
        resolvedConversion:
            _rate(delivered.length, delivered.length + lost.length),
        dealValue: _valueProfile(group),
        deliveredValue: deliveredValue,
        deliveredValueShare: deliveredValueShare,
        activeOpportunityValue: _sumValue(group.where((lead) => lead.isActive)),
        funnel: funnel(group),
        lossReasons: _reasonCounts(group),
        economicImportanceIndex: leadShare == null || leadShare == 0
            ? null
            : deliveredValueShare == null
                ? null
                : deliveredValueShare / leadShare,
      );
    }).toList(growable: false);
  }

  List<LostReasonAnalytics> lostReasons([Iterable<AnalyticalLead>? scope]) {
    final lost = _list(scope).where((lead) => lead.isLost).toList();
    final groups =
        _groupBy<AnalyticalLead, String?>(lost, (lead) => lead.lead.lostReason);
    return groups.entries.map((entry) {
      final group = entry.value;
      return LostReasonAnalytics(
        reason: entry.key,
        total: _lossBreakdown(group),
        byStage: _breakdownBy(group, (lead) => lead.lostFromStage),
        byBranch: _breakdownBy(group, (lead) => lead.branchId),
        bySource: _breakdownBy(group, (lead) => lead.source),
        byModel: _breakdownBy(group, (lead) => lead.vehicleModel),
        byRep: _breakdownBy(group, (lead) => lead.repId),
      );
    }).toList(growable: false);
  }

  List<PipelineOpportunity> pipeline([Iterable<AnalyticalLead>? scope]) =>
      _list(scope).where((lead) => lead.isActive).map((lead) {
        final ageDays = _nonNegativeDays(
            dataset.context.snapshotDate.difference(lead.lead.createdAt));
        return PipelineOpportunity(
          leadId: lead.id,
          stage: lead.currentFunnelStage,
          ageDays: ageDays,
          inactivityDays: lead.daysSinceLastActivity,
          ageingBand: _ageingBand(lead.daysSinceLastActivity),
          expectedCloseSlippage: lead.expectedCloseSlippage,
          dealValue: lead.dealValue,
          branchId: lead.branchId,
          repId: lead.repId,
          isOverdueOrderStage:
              lead.currentFunnelStage == FunnelStage.orderPlaced &&
                  lead.expectedCloseOverdue,
        );
      }).toList(growable: false);

  PipelineOperationalAnalytics pipelineOperations(
      [Iterable<AnalyticalLead>? scope]) {
    final opportunities = pipeline(scope);
    final stale = opportunities.where((item) =>
        item.ageingBand == PipelineAgeingBand.stale ||
        item.ageingBand == PipelineAgeingBand.severelyStale);
    final overdue = opportunities
        .where((item) => item.expectedCloseSlippage != null)
        .toList(growable: false);
    final orders = opportunities
        .where((item) => item.stage == FunnelStage.orderPlaced)
        .toList(growable: false);
    final oldest = [...opportunities]
      ..sort((a, b) => b.ageDays.compareTo(a.ageDays));
    return PipelineOperationalAnalytics(
      activeCount: opportunities.length,
      activeValue: _pipelineValue(opportunities),
      staleValue: _pipelineValue(stale),
      byStage: _pipelineBuckets(opportunities, (item) => item.stage),
      byInactivity: _pipelineBuckets(opportunities, (item) => item.ageingBand),
      byAge:
          _pipelineBuckets(opportunities, (item) => _ageingBand(item.ageDays)),
      byBranch: _pipelineBuckets(opportunities, (item) => item.branchId),
      byRep: _pipelineBuckets(opportunities, (item) => item.repId),
      overdueExpectedClose: _pipelineBucket(overdue),
      orderStageBacklog: _pipelineBucket(orders),
      oldest: oldest.take(20).toList(growable: false),
      thresholds: ageingConfig,
    );
  }

  DeliveryAnalytics deliveries([Iterable<AnalyticalLead>? scope]) {
    final leads = _list(scope);
    final leadById = {for (final lead in leads) lead.id: lead};
    final deliveries = dataset.source.deliveries
        .where((delivery) => leadById.containsKey(delivery.leadId))
        .toList();
    final noDelay =
        deliveries.where((delivery) => delivery.delayReason == null).toList();
    final baseline = _averageDays(noDelay);
    final reasonGroups = _groupBy<Delivery, String>(
      deliveries.where((delivery) => delivery.delayReason != null),
      (delivery) => delivery.delayReason!,
    );
    final byBranch = _groupBy<Delivery, String>(
      deliveries,
      (delivery) => leadById[delivery.leadId]!.branchId,
    );
    final byVehicle = _groupBy<Delivery, String>(
      deliveries,
      (delivery) => leadById[delivery.leadId]!.vehicleModel,
    );
    var timely = 0;
    for (final delivery in deliveries) {
      final lead = leadById[delivery.leadId]!;
      if (!delivery.deliveryDate.isAfter(lead.lead.expectedCloseDate)) timely++;
    }
    return DeliveryAnalytics(
      overall: _deliveryStats(deliveries),
      withoutRecordedDelay: _deliveryStats(noDelay),
      delayReasons: reasonGroups.entries.map((entry) {
        final average = _averageDays(entry.value);
        return DelayReasonAnalytics(
          reason: entry.key,
          stats: _deliveryStats(entry.value),
          incrementalAverageDays:
              average == null || baseline == null ? null : average - baseline,
        );
      }).toList(growable: false),
      byBranch: {
        for (final entry in byBranch.entries)
          entry.key: _deliveryStats(entry.value),
      },
      byVehicle: {
        for (final entry in byVehicle.entries)
          entry.key: _deliveryStats(entry.value),
      },
      expectedCloseLinkedCount: deliveries.length,
      deliveredByExpectedCloseCount: timely,
    );
  }

  List<CohortAnalytics> cohorts([Iterable<AnalyticalLead>? scope]) {
    final leads = _list(scope);
    final groups = _groupBy<AnalyticalLead, DateTime>(
      leads,
      (lead) => DateTime(lead.lead.createdAt.year, lead.lead.createdAt.month),
    );
    final maturity = dataset.context.maturityDuration;
    final results = groups.entries.map((entry) {
      final delivered = entry.value.where((lead) => lead.isDelivered).length;
      final lost = entry.value.where((lead) => lead.isLost).length;
      final monthAfter = DateTime(entry.key.year, entry.key.month + 1);
      final mature = maturity != null &&
          !monthAfter.add(maturity).isAfter(dataset.context.snapshotDate);
      return CohortAnalytics(
        month: entry.key,
        leadVolume: entry.value.length,
        delivered: delivered,
        lost: lost,
        active: entry.value.where((lead) => lead.isActive).length,
        resolvedConversion: _rate(delivered, delivered + lost),
        isMature: mature,
      );
    }).toList()
      ..sort((left, right) => left.month.compareTo(right.month));
    return results;
  }

  SegmentAnalytics _segment(List<AnalyticalLead> leads) {
    final overview = businessOverview(leads);
    return SegmentAnalytics(
      leadVolume: overview.totalLeads,
      active: overview.activeLeads,
      resolved: overview.resolvedLeads,
      delivered: overview.delivered,
      lost: overview.lost,
      resolvedConversion: overview.resolvedConversion,
      funnel: funnel(leads),
      activeOpportunityValue: overview.activeOpportunityValue,
      deliveredDealValue: overview.deliveredDealValue,
      dealValue: overview.dealValue,
    );
  }

  ManagementGateResult _gate(
    ManagementGate gate,
    Iterable<AnalyticalLead> eligible,
    Iterable<AnalyticalLead> reached,
    Iterable<AnalyticalLead> lostBefore,
  ) {
    final eligibleList = eligible.toList();
    final reachedList = reached.toList();
    final lostList = lostBefore.toList();
    return ManagementGateResult(
      gate: gate,
      eligibleCount: eligibleList.length,
      reachedCount: reachedList.length,
      conversion: _rate(reachedList.length, eligibleList.length),
      lostBeforeGateCount: lostList.length,
      lostBeforeGateValue: _sumValue(lostList),
    );
  }

  PipelineAgeingSummary _pipelineSummary(List<AnalyticalLead> leads) {
    final bands = pipeline(leads).map((item) => item.ageingBand).toList();
    return PipelineAgeingSummary(
      recentlyActive: bands
          .where((band) => band == PipelineAgeingBand.recentlyActive)
          .length,
      ageing: bands.where((band) => band == PipelineAgeingBand.ageing).length,
      stale: bands.where((band) => band == PipelineAgeingBand.stale).length,
      severelyStale: bands
          .where((band) => band == PipelineAgeingBand.severelyStale)
          .length,
    );
  }

  PipelineAgeingBand _ageingBand(int days) {
    if (days >= ageingConfig.severelyStaleAfterDays) {
      return PipelineAgeingBand.severelyStale;
    }
    if (days >= ageingConfig.staleAfterDays) return PipelineAgeingBand.stale;
    if (days >= ageingConfig.ageingAfterDays) return PipelineAgeingBand.ageing;
    return PipelineAgeingBand.recentlyActive;
  }

  static Map<K, PipelineBucket> _pipelineBuckets<K>(
      Iterable<PipelineOpportunity> items,
      K Function(PipelineOpportunity) keyOf) {
    final groups = <K, List<PipelineOpportunity>>{};
    for (final item in items) {
      groups.putIfAbsent(keyOf(item), () => []).add(item);
    }
    return {
      for (final entry in groups.entries)
        entry.key: _pipelineBucket(entry.value),
    };
  }

  static PipelineBucket _pipelineBucket(Iterable<PipelineOpportunity> items) =>
      PipelineBucket(
        count: items.length,
        value: _pipelineValue(items),
        leadIds: items.map((item) => item.leadId),
      );

  static num _pipelineValue(Iterable<PipelineOpportunity> items) =>
      items.fold<num>(0, (sum, item) => sum + item.dealValue);

  List<AnalyticalLead> _list(Iterable<AnalyticalLead>? scope) =>
      (scope ?? dataset.leads).toList(growable: false);

  static bool _reached(AnalyticalLead lead, FunnelStage stage) =>
      switch (stage) {
        FunnelStage.newLead => true,
        FunnelStage.contacted => lead.reachedContacted,
        FunnelStage.testDrive => lead.reachedTestDrive,
        FunnelStage.negotiation => lead.reachedNegotiation,
        FunnelStage.orderPlaced => lead.reachedOrderPlaced,
        FunnelStage.delivered => lead.reachedDelivered,
      };

  static FunnelStage? _nextStage(FunnelStage stage) => switch (stage) {
        FunnelStage.newLead => FunnelStage.contacted,
        FunnelStage.contacted => FunnelStage.testDrive,
        FunnelStage.testDrive => FunnelStage.negotiation,
        FunnelStage.negotiation => FunnelStage.orderPlaced,
        FunnelStage.orderPlaced => FunnelStage.delivered,
        FunnelStage.delivered => null,
      };

  static Duration? _transitionDuration(
          AnalyticalLead lead, FunnelStage stage) =>
      switch (stage) {
        FunnelStage.newLead => lead.newToContacted,
        FunnelStage.contacted => lead.contactedToTestDrive,
        FunnelStage.testDrive => lead.testDriveToNegotiation,
        FunnelStage.negotiation => lead.negotiationToOrder,
        FunnelStage.orderPlaced => lead.orderToDelivery,
        FunnelStage.delivered => null,
      };

  static ValueProfile _valueProfile(Iterable<AnalyticalLead> leads) {
    final values = leads.map((lead) => lead.dealValue.toDouble()).toList();
    return ValueProfile(
      total: values.fold<double>(0, (sum, value) => sum + value),
      average: _average(values),
      median: _percentile(values, 0.5),
    );
  }

  static num _sumValue(Iterable<AnalyticalLead> leads) =>
      leads.fold<num>(0, (sum, lead) => sum + lead.dealValue);

  static double? _rate(num numerator, num denominator) =>
      denominator == 0 ? null : numerator / denominator;

  static double? _ratio(num numerator, num denominator) =>
      denominator == 0 ? null : numerator / denominator;

  static Map<String?, int> _reasonCounts(Iterable<AnalyticalLead> leads) {
    final result = <String?, int>{};
    for (final lead in leads.where((lead) => lead.isLost)) {
      result.update(lead.lead.lostReason, (count) => count + 1,
          ifAbsent: () => 1);
    }
    return result;
  }

  static Map<K, List<T>> _groupBy<T, K>(
    Iterable<T> values,
    K Function(T value) key,
  ) {
    final result = <K, List<T>>{};
    for (final value in values) {
      result.putIfAbsent(key(value), () => []).add(value);
    }
    return result;
  }

  static LossBreakdown _lossBreakdown(Iterable<AnalyticalLead> leads) {
    final list = leads.toList();
    return LossBreakdown(count: list.length, affectedValue: _sumValue(list));
  }

  static Map<K, LossBreakdown> _breakdownBy<K>(
    Iterable<AnalyticalLead> leads,
    K? Function(AnalyticalLead lead) key,
  ) {
    final groups = <K, List<AnalyticalLead>>{};
    for (final lead in leads) {
      final value = key(lead);
      if (value != null) groups.putIfAbsent(value, () => []).add(lead);
    }
    return {
      for (final entry in groups.entries) entry.key: _lossBreakdown(entry.value)
    };
  }

  static DeliveryStats _deliveryStats(List<Delivery> deliveries) {
    final days = deliveries
        .map((delivery) => delivery.daysToDeliver.toDouble())
        .toList();
    return DeliveryStats(
      count: deliveries.length,
      averageDays: _average(days),
      medianDays: _percentile(days, 0.5),
      p80Days: _percentile(days, 0.8),
      p90Days: _percentile(days, 0.9),
    );
  }

  static double? _averageDays(List<Delivery> deliveries) => _average(
      deliveries.map((delivery) => delivery.daysToDeliver.toDouble()).toList());

  static double? _average(List<double> values) => values.isEmpty
      ? null
      : values.fold<double>(0, (sum, value) => sum + value) / values.length;

  static double? _percentile(List<double> values, double percentile) {
    if (values.isEmpty) return null;
    final sorted = [...values]..sort();
    if (sorted.length == 1) return sorted.single;
    final position = percentile * (sorted.length - 1);
    final lower = position.floor();
    final upper = position.ceil();
    return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - lower);
  }

  static Duration? _averageDuration(List<Duration> values) {
    if (values.isEmpty) return null;
    final total =
        values.fold<int>(0, (sum, value) => sum + value.inMicroseconds);
    return Duration(microseconds: (total / values.length).round());
  }

  static Duration? _medianDuration(List<Duration> values) {
    final median = _percentile(
        values.map((value) => value.inMicroseconds.toDouble()).toList(), 0.5);
    return median == null ? null : Duration(microseconds: median.round());
  }

  static int _nonNegativeDays(Duration duration) =>
      duration.isNegative ? 0 : duration.inDays;
}
