import 'analytical_lead.dart';

final class ValueProfile {
  const ValueProfile({
    required this.total,
    required this.average,
    required this.median,
  });

  final num total;
  final double? average;
  final double? median;
}

final class BusinessOverview {
  const BusinessOverview({
    required this.totalLeads,
    required this.activeLeads,
    required this.resolvedLeads,
    required this.delivered,
    required this.lost,
    required this.resolvedConversion,
    required this.activeOpportunityValue,
    required this.deliveredDealValue,
    required this.dealValue,
  });

  final int totalLeads;
  final int activeLeads;
  final int resolvedLeads;
  final int delivered;
  final int lost;
  final double? resolvedConversion;
  final num activeOpportunityValue;
  final num deliveredDealValue;
  final ValueProfile dealValue;
}

final class FunnelStageResult {
  const FunnelStageResult({
    required this.stage,
    required this.reachedCount,
    required this.progressionCount,
    required this.progressionRate,
    required this.leakageCount,
    required this.leakageRate,
    required this.leakageValue,
    required this.leakedLeadIds,
    required this.averageTransitionDuration,
    required this.medianTransitionDuration,
  });

  final FunnelStage stage;
  final int reachedCount;
  final int progressionCount;
  final double? progressionRate;
  final int leakageCount;
  final double? leakageRate;
  final num leakageValue;
  final List<String> leakedLeadIds;
  final Duration? averageTransitionDuration;
  final Duration? medianTransitionDuration;
}

enum ManagementGate { contact, testDrive, close }

final class ManagementGateResult {
  const ManagementGateResult({
    required this.gate,
    required this.eligibleCount,
    required this.reachedCount,
    required this.conversion,
    required this.lostBeforeGateCount,
    required this.lostBeforeGateValue,
    required this.lostBeforeGateLeadIds,
  });

  final ManagementGate gate;
  final int eligibleCount;
  final int reachedCount;
  final double? conversion;
  final int lostBeforeGateCount;
  final num lostBeforeGateValue;
  final List<String> lostBeforeGateLeadIds;
}

final class PipelineAgeingSummary {
  const PipelineAgeingSummary({
    required this.recentlyActive,
    required this.ageing,
    required this.stale,
    required this.severelyStale,
  });

  final int recentlyActive;
  final int ageing;
  final int stale;
  final int severelyStale;
}

final class DeliveryStats {
  const DeliveryStats({
    required this.count,
    required this.averageDays,
    required this.medianDays,
    required this.p80Days,
    required this.p90Days,
  });

  final int count;
  final double? averageDays;
  final double? medianDays;
  final double? p80Days;
  final double? p90Days;
}

final class SegmentAnalytics {
  const SegmentAnalytics({
    required this.leadVolume,
    required this.active,
    required this.resolved,
    required this.delivered,
    required this.lost,
    required this.resolvedConversion,
    required this.funnel,
    required this.activeOpportunityValue,
    required this.deliveredDealValue,
    required this.dealValue,
  });

  final int leadVolume;
  final int active;
  final int resolved;
  final int delivered;
  final int lost;
  final double? resolvedConversion;
  final List<FunnelStageResult> funnel;
  final num activeOpportunityValue;
  final num deliveredDealValue;
  final ValueProfile dealValue;
}

final class BranchAnalytics {
  const BranchAnalytics({
    required this.branchId,
    required this.branchName,
    required this.metrics,
    required this.workloadPerSalesOfficer,
    required this.lostReasons,
    required this.pipelineAgeing,
    required this.staleOpportunityValue,
    required this.staleOpportunityShare,
    required this.deliveryPerformance,
  });

  final String branchId;
  final String branchName;
  final SegmentAnalytics metrics;
  final double? workloadPerSalesOfficer;
  final Map<String?, int> lostReasons;
  final PipelineAgeingSummary pipelineAgeing;
  final num staleOpportunityValue;
  final double? staleOpportunityShare;
  final DeliveryStats deliveryPerformance;
}

final class SalesRepAnalytics {
  const SalesRepAnalytics({
    required this.repId,
    required this.repName,
    required this.branchId,
    required this.branchName,
    required this.metrics,
  });

  final String repId;
  final String repName;
  final String branchId;
  final String? branchName;
  final SegmentAnalytics metrics;
}

final class SourceAnalytics {
  const SourceAnalytics({
    required this.source,
    required this.volume,
    required this.contactRate,
    required this.testDriveRate,
    required this.rawDeliveredRate,
    required this.resolvedConversion,
    required this.deliveredAmongContacted,
    required this.testDriveAmongContacted,
    required this.activeValue,
    required this.deliveredValue,
  });

  final String? source;
  final int volume;
  final double? contactRate;
  final double? testDriveRate;
  final double? rawDeliveredRate;
  final double? resolvedConversion;
  final double? deliveredAmongContacted;
  final double? testDriveAmongContacted;
  final num activeValue;
  final num deliveredValue;
}

final class VehicleAnalytics {
  const VehicleAnalytics({
    required this.model,
    required this.leadCount,
    required this.leadShare,
    required this.deliveredCount,
    required this.deliveredShare,
    required this.resolvedConversion,
    required this.dealValue,
    required this.deliveredValue,
    required this.deliveredValueShare,
    required this.activeOpportunityValue,
    required this.funnel,
    required this.lossReasons,
    required this.economicImportanceIndex,
  });

  final String model;
  final int leadCount;
  final double? leadShare;
  final int deliveredCount;
  final double? deliveredShare;
  final double? resolvedConversion;
  final ValueProfile dealValue;
  final num deliveredValue;
  final double? deliveredValueShare;
  final num activeOpportunityValue;
  final List<FunnelStageResult> funnel;
  final Map<String?, int> lossReasons;

  /// Delivered-value share divided by lead share. This is not profitability.
  final double? economicImportanceIndex;
}

final class LossBreakdown {
  const LossBreakdown({required this.count, required this.affectedValue});

  final int count;
  final num affectedValue;
}

final class LostReasonAnalytics {
  const LostReasonAnalytics({
    required this.reason,
    required this.total,
    required this.byStage,
    required this.byBranch,
    required this.bySource,
    required this.byModel,
    required this.byRep,
  });

  final String? reason;
  final LossBreakdown total;
  final Map<FunnelStage, LossBreakdown> byStage;
  final Map<String, LossBreakdown> byBranch;
  final Map<String?, LossBreakdown> bySource;
  final Map<String, LossBreakdown> byModel;
  final Map<String, LossBreakdown> byRep;
}

enum PipelineAgeingBand { recentlyActive, ageing, stale, severelyStale }

final class PipelineAgeingConfig {
  const PipelineAgeingConfig({
    this.ageingAfterDays = 7,
    this.staleAfterDays = 14,
    this.severelyStaleAfterDays = 30,
  })  : assert(ageingAfterDays >= 0),
        assert(staleAfterDays > ageingAfterDays),
        assert(severelyStaleAfterDays > staleAfterDays);

  final int ageingAfterDays;
  final int staleAfterDays;
  final int severelyStaleAfterDays;
}

final class PipelineOpportunity {
  const PipelineOpportunity({
    required this.leadId,
    required this.stage,
    required this.ageDays,
    required this.inactivityDays,
    required this.ageingBand,
    required this.expectedCloseSlippage,
    required this.dealValue,
    required this.branchId,
    required this.repId,
    required this.isOverdueOrderStage,
  });

  final String leadId;
  final FunnelStage? stage;
  final int ageDays;
  final int inactivityDays;
  final PipelineAgeingBand ageingBand;
  final Duration? expectedCloseSlippage;
  final num dealValue;
  final String branchId;
  final String repId;
  final bool isOverdueOrderStage;
}

final class PipelineBucket {
  PipelineBucket({
    required this.count,
    required this.value,
    required Iterable<String> leadIds,
  }) : leadIds = List.unmodifiable(leadIds);

  final int count;
  final num value;
  final List<String> leadIds;
}

/// Aggregated active-pipeline operations calculated by the analytics engine.
final class PipelineOperationalAnalytics {
  const PipelineOperationalAnalytics({
    required this.activeCount,
    required this.activeValue,
    required this.staleValue,
    required this.byStage,
    required this.byInactivity,
    required this.byAge,
    required this.byBranch,
    required this.byRep,
    required this.overdueExpectedClose,
    required this.orderStageBacklog,
    required this.oldest,
    required this.thresholds,
  });

  final int activeCount;
  final num activeValue;
  final num staleValue;
  final Map<FunnelStage?, PipelineBucket> byStage;
  final Map<PipelineAgeingBand, PipelineBucket> byInactivity;
  final Map<PipelineAgeingBand, PipelineBucket> byAge;
  final Map<String, PipelineBucket> byBranch;
  final Map<String, PipelineBucket> byRep;
  final PipelineBucket overdueExpectedClose;
  final PipelineBucket orderStageBacklog;
  final List<PipelineOpportunity> oldest;
  final PipelineAgeingConfig thresholds;
}

final class DelayReasonAnalytics {
  const DelayReasonAnalytics({
    required this.reason,
    required this.stats,
    required this.incrementalAverageDays,
  });

  final String reason;
  final DeliveryStats stats;
  final double? incrementalAverageDays;
}

final class DeliveryAnalytics {
  const DeliveryAnalytics({
    required this.overall,
    required this.withoutRecordedDelay,
    required this.delayReasons,
    required this.byBranch,
    required this.byVehicle,
    required this.expectedCloseLinkedCount,
    required this.deliveredByExpectedCloseCount,
  });

  final DeliveryStats overall;
  final DeliveryStats withoutRecordedDelay;
  final List<DelayReasonAnalytics> delayReasons;
  final Map<String, DeliveryStats> byBranch;
  final Map<String, DeliveryStats> byVehicle;
  final int expectedCloseLinkedCount;
  final int deliveredByExpectedCloseCount;
}

final class CohortAnalytics {
  const CohortAnalytics({
    required this.month,
    required this.leadVolume,
    required this.delivered,
    required this.lost,
    required this.active,
    required this.resolvedConversion,
    required this.isMature,
  });

  final DateTime month;
  final int leadVolume;
  final int delivered;
  final int lost;
  final int active;
  final double? resolvedConversion;
  final bool isMature;
}
