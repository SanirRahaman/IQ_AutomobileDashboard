import 'dart:math' as math;

import '../../analytics/models/analytical_lead.dart';
import '../../analytics/services/dealership_analytics_engine.dart';
import '../../data/validation/validation.dart';
import '../models/insight_engine_config.dart';
import '../models/management_insight.dart';

final class DeterministicInsightEngine {
  const DeterministicInsightEngine({
    this.config = const InsightEngineConfig(),
  });

  final InsightEngineConfig config;

  List<ManagementInsight> generate(
    AnalyticalDataset dataset, {
    AnalyticalDataset? deliveryDataset,
    ValidationReport? validationReport,
    int? limit,
  }) {
    final analytics = DealershipAnalyticsEngine(dataset);
    final deliveryScope = deliveryDataset ?? dataset;
    final deliveryAnalytics = DealershipAnalyticsEngine(deliveryScope);
    final candidates = <_DraftInsight>[
      ..._funnelInsights(dataset, analytics),
      ..._branchInsights(dataset, analytics, deliveryScope, deliveryAnalytics),
      ..._repInsights(dataset, analytics),
      ..._sourceInsights(dataset, analytics),
      ..._vehicleInsights(dataset, analytics),
      ..._pipelineInsights(dataset, analytics),
      ..._deliveryInsights(deliveryScope, deliveryAnalytics),
      ..._dataQualityInsights(dataset, validationReport),
    ];
    final totalValue = dataset.leads.fold<double>(
      0,
      (sum, lead) => sum + lead.dealValue.toDouble(),
    );
    final insights = candidates
        .map((draft) => _rank(draft, totalValue))
        .toList(growable: false)
      ..sort((left, right) {
        final score = right.rankScore.compareTo(left.rankScore);
        return score != 0 ? score : left.id.compareTo(right.id);
      });
    if (limit != null) {
      return insights.take(limit).toList(growable: false);
    }
    return _selectOverview(insights, config.defaultLimit);
  }

  List<ManagementInsight> _selectOverview(
    List<ManagementInsight> ranked,
    int limit,
  ) {
    final selected = <ManagementInsight>[];
    final categoryCounts = <InsightCategory, int>{};
    final families = <String>{};
    final dimensionSignatures = <String>{};
    for (final insight in ranked) {
      final family = _ruleFamily(insight.id);
      final signature = _dimensionSignature(insight);
      if ((categoryCounts[insight.category] ?? 0) >= 2 ||
          families.contains(family) ||
          dimensionSignatures.contains(signature)) {
        continue;
      }
      selected.add(insight);
      categoryCounts.update(insight.category, (count) => count + 1,
          ifAbsent: () => 1);
      families.add(family);
      dimensionSignatures.add(signature);
      if (selected.length == limit) return selected;
    }
    for (final insight in ranked) {
      final signature = _dimensionSignature(insight);
      if (selected.contains(insight) ||
          (categoryCounts[insight.category] ?? 0) >= 2 ||
          dimensionSignatures.contains(signature)) {
        continue;
      }
      selected.add(insight);
      categoryCounts.update(insight.category, (count) => count + 1,
          ifAbsent: () => 1);
      dimensionSignatures.add(signature);
      if (selected.length == limit) return selected;
    }
    return selected;
  }

  List<_DraftInsight> _funnelInsights(
    AnalyticalDataset dataset,
    DealershipAnalyticsEngine analytics,
  ) {
    final insights = <_DraftInsight>[];
    final leads = dataset.leads;
    final lost = leads.where((lead) => lead.isLost).toList();
    final earlyLosses = lost
        .where((lead) =>
            lead.lostFromStage == FunnelStage.newLead ||
            lead.lostFromStage == FunnelStage.contacted)
        .toList();
    final earlyRate = _rate(earlyLosses.length, lost.length);
    if (lost.length >= config.minimumResolvedLeads &&
        earlyRate != null &&
        earlyRate >= 0.5) {
      insights.add(_draft(
        id: 'funnel.loss_before_test_drive',
        category: InsightCategory.funnel,
        severity: earlyRate >= 0.7
            ? InsightSeverity.critical
            : InsightSeverity.warning,
        title: 'Most losses occur before test drive',
        finding:
            '${_percent(earlyRate)} of resolved losses exit before reaching test drive.',
        significance:
            'Early-stage leakage limits the number of opportunities that reach an experiential sales gate.',
        metric: InsightMetric(
          key: 'early_loss_share',
          label: 'Share of losses before test drive',
          value: earlyRate,
          unit: MetricUnit.rate,
          numerator: earlyLosses.length,
          denominator: lost.length,
        ),
        benchmark: const InsightBenchmark(
          label: 'Majority threshold',
          value: 0.5,
          unit: MetricUnit.rate,
          method: 'explicit management threshold',
          sampleSize: 0,
        ),
        affected: earlyLosses,
        affectedValue: _sumValue(earlyLosses),
        minimumSupport: config.minimumResolvedLeads,
        investigation:
            'Review first-contact timing, qualification, and the records lost before test drive without assigning cause in advance.',
        reason:
            'Generated because at least half of sufficiently supported losses occurred at new or contacted.',
        urgency: 0.7,
      ));
    }

    final funnel = analytics.funnel();
    final supportedRates = funnel
        .where((stage) =>
            stage.progressionRate != null &&
            stage.reachedCount >= config.minimumStageLeads)
        .map((stage) => 1 - stage.progressionRate!)
        .toList();
    final medianLeakage = _median(supportedRates);
    if (medianLeakage != null) {
      for (final stage in funnel.where((item) =>
          item.progressionRate != null &&
          item.reachedCount >= config.minimumStageLeads)) {
        final leakageRate = 1 - stage.progressionRate!;
        final difference = leakageRate - medianLeakage;
        if (difference < config.minimumRateDifference || leakageRate < 0.2) {
          continue;
        }
        final affected = leads
            .where((lead) => lead.isLost && lead.lostFromStage == stage.stage)
            .toList();
        if (affected.isEmpty) continue;
        insights.add(_draft(
          id: 'funnel.high_leakage.${stage.stage.name}',
          category: InsightCategory.funnel,
          severity: leakageRate >= 0.5
              ? InsightSeverity.critical
              : InsightSeverity.warning,
          title: 'Elevated leakage after ${_stageName(stage.stage)}',
          finding:
              '${_percent(leakageRate)} fail to progress from ${_stageName(stage.stage)}, versus a ${_percent(medianLeakage)} median across supported funnel stages.',
          significance:
              'This stage removes a disproportionate share of opportunities from the sales journey.',
          metric: InsightMetric(
            key: 'stage_leakage_rate',
            label: '${_stageName(stage.stage)} leakage',
            value: leakageRate,
            unit: MetricUnit.rate,
            numerator: stage.reachedCount - stage.progressionCount,
            denominator: stage.reachedCount,
          ),
          benchmark: InsightBenchmark(
            label: 'Supported-stage median leakage',
            value: medianLeakage,
            unit: MetricUnit.rate,
            method: 'median of funnel-stage leakage rates',
            sampleSize: supportedRates.length,
          ),
          affected: affected,
          affectedValue: _sumValue(affected),
          minimumSupport: config.minimumStageLeads,
          investigation:
              'Inspect the affected records and transition handling around ${_stageName(stage.stage)}.',
          reason:
              'Generated because stage leakage exceeded the supported-stage median by at least ${_percent(config.minimumRateDifference)}.',
          urgency: 0.5,
        ));
      }
    }

    for (final stage in FunnelStage.values
        .where((stage) => stage != FunnelStage.delivered)) {
      final durations = leads
          .map((lead) => _transitionDuration(lead, stage))
          .whereType<Duration>()
          .toList();
      if (durations.length < config.minimumStageLeads) continue;
      final days = durations.map((duration) => duration.inHours / 24).toList();
      final median = _median(days)!;
      final p90 = _percentile(days, 0.9)!;
      if (median <= 0 || p90 < median * 2 || p90 - median < 2) continue;
      final affected = leads.where((lead) {
        final duration = _transitionDuration(lead, stage);
        return duration != null && duration.inHours / 24 >= p90;
      }).toList();
      insights.add(_draft(
        id: 'funnel.slow_tail.${stage.name}',
        category: InsightCategory.funnel,
        severity: InsightSeverity.warning,
        title: 'Long tail in ${_stageName(stage)} progression',
        finding:
            'The slowest decile takes at least ${p90.toStringAsFixed(1)} days to progress, compared with a ${median.toStringAsFixed(1)}-day median.',
        significance:
            'A material slow tail can conceal follow-up or process bottlenecks even when the typical journey is faster.',
        metric: InsightMetric(
          key: 'transition_p90_days',
          label: '${_stageName(stage)} transition p90',
          value: p90,
          unit: MetricUnit.days,
          denominator: durations.length,
        ),
        benchmark: InsightBenchmark(
          label: 'Transition median',
          value: median,
          unit: MetricUnit.days,
          method: 'median of valid observed transition durations',
          sampleSize: durations.length,
        ),
        affected: affected,
        affectedValue: _sumValue(affected),
        minimumSupport: config.minimumStageLeads,
        investigation:
            'Review the slowest transition records for common hand-off or follow-up patterns.',
        reason:
            'Generated because the transition p90 is at least twice the median and at least two days slower.',
        urgency: 0.4,
      ));
    }
    return insights;
  }

  List<_DraftInsight> _branchInsights(
    AnalyticalDataset dataset,
    DealershipAnalyticsEngine analytics,
    AnalyticalDataset deliveryDataset,
    DealershipAnalyticsEngine deliveryAnalytics,
  ) {
    final insights = <_DraftInsight>[];
    final network = analytics.businessOverview();
    final benchmark = network.resolvedConversion;
    if (benchmark == null) return insights;
    final networkFunnel = analytics.funnel();
    final branchResults = analytics.branches();
    final workloadMedian = _median(branchResults
        .map((branch) => branch.workloadPerSalesOfficer)
        .whereType<double>()
        .toList());
    final networkDeliveryMedian =
        deliveryAnalytics.deliveries().overall.medianDays;
    final deliveryBranches = {
      for (final branch in deliveryAnalytics.branches())
        branch.branchId: branch,
    };
    for (final branch in branchResults) {
      final records = dataset.leads
          .where((lead) => lead.branchId == branch.branchId)
          .toList();
      final conversion = branch.metrics.resolvedConversion;
      if (conversion != null &&
          branch.metrics.resolved >= config.minimumResolvedLeads &&
          benchmark - conversion >= config.minimumRateDifference) {
        insights.add(_draft(
          id: 'branch.low_conversion.${_id(branch.branchId)}',
          category: InsightCategory.branch,
          severity: benchmark - conversion >= 0.2
              ? InsightSeverity.critical
              : InsightSeverity.warning,
          title: '${branch.branchName} converts below the network',
          finding:
              'Resolved conversion is ${_percent(conversion)}, compared with ${_percent(benchmark)} network-wide.',
          significance:
              'The supported conversion gap affects resolved sales outcomes and associated deal value.',
          metric: InsightMetric(
            key: 'resolved_conversion',
            label: 'Branch resolved conversion',
            value: conversion,
            unit: MetricUnit.rate,
            numerator: branch.metrics.delivered,
            denominator: branch.metrics.resolved,
          ),
          benchmark: InsightBenchmark(
            label: 'Network resolved conversion',
            value: benchmark,
            unit: MetricUnit.rate,
            method: 'all resolved leads in scope',
            sampleSize: network.resolvedLeads,
          ),
          affected: records.where((lead) => lead.isResolved).toList(),
          affectedValue:
              _sumValue(records.where((lead) => lead.isLost).toList()),
          minimumSupport: config.minimumResolvedLeads,
          dimensions: InsightDimensions(branchIds: [branch.branchId]),
          investigation:
              'Compare stage progression, loss reasons, and follow-up timing with peer branches.',
          reason:
              'Generated because supported branch conversion is at least ${_percent(config.minimumRateDifference)} below the network benchmark.',
          urgency: 0.6,
        ));
      }

      var weakStages = 0;
      for (var index = 0; index < branch.metrics.funnel.length; index++) {
        final branchStage = branch.metrics.funnel[index];
        final networkStage = networkFunnel[index];
        if (branchStage.reachedCount >= config.minimumStageLeads &&
            branchStage.progressionRate != null &&
            networkStage.progressionRate != null &&
            networkStage.progressionRate! - branchStage.progressionRate! >=
                config.minimumRateDifference) {
          weakStages++;
        }
      }
      if (weakStages >= 2) {
        insights.add(_draft(
          id: 'branch.multi_stage_gap.${_id(branch.branchId)}',
          category: InsightCategory.branch,
          severity: InsightSeverity.warning,
          title: '${branch.branchName} trails at several funnel stages',
          finding:
              '$weakStages supported stage-progression rates are materially below their network benchmarks.',
          significance:
              'Multiple stage gaps suggest the performance difference is not isolated to one hand-off.',
          metric: InsightMetric(
            key: 'underperforming_stage_count',
            label: 'Stages below benchmark',
            value: weakStages.toDouble(),
            unit: MetricUnit.count,
          ),
          benchmark: const InsightBenchmark(
            label: 'Multi-stage trigger',
            value: 2,
            unit: MetricUnit.count,
            method: 'explicit rule threshold',
            sampleSize: 0,
          ),
          affected: records,
          affectedValue:
              _sumValue(records.where((lead) => lead.isLost).toList()),
          minimumSupport: config.minimumStageLeads,
          dimensions: InsightDimensions(branchIds: [branch.branchId]),
          investigation:
              'Review each below-benchmark transition separately before selecting a corrective action.',
          reason:
              'Generated because at least two supported funnel stages trail network progression by the configured material difference.',
          urgency: 0.5,
        ));
      }

      if (conversion != null &&
          workloadMedian != null &&
          branch.workloadPerSalesOfficer != null &&
          branch.workloadPerSalesOfficer! < workloadMedian * 0.75 &&
          branch.metrics.resolved >= config.minimumResolvedLeads &&
          benchmark - conversion >= config.minimumRateDifference) {
        insights.add(_draft(
          id: 'branch.low_workload_low_conversion.${_id(branch.branchId)}',
          category: InsightCategory.branch,
          severity: InsightSeverity.opportunity,
          title: '${branch.branchName} has capacity and a conversion gap',
          finding:
              'Workload per sales officer is below the branch median while resolved conversion trails the network.',
          significance:
              'Available capacity may allow focused process review without first increasing staffing.',
          metric: InsightMetric(
            key: 'workload_per_sales_officer',
            label: 'Leads per sales officer',
            value: branch.workloadPerSalesOfficer!,
            unit: MetricUnit.ratio,
          ),
          benchmark: InsightBenchmark(
            label: 'Branch median workload',
            value: workloadMedian,
            unit: MetricUnit.ratio,
            method: 'median across branches with sales officers',
            sampleSize: branchResults.length,
          ),
          affected: records,
          affectedValue:
              _sumValue(records.where((lead) => lead.isLost).toList()),
          minimumSupport: config.minimumResolvedLeads,
          dimensions: InsightDimensions(branchIds: [branch.branchId]),
          investigation:
              'Review assignment balance, activity cadence, and stage handling before changing lead volume.',
          reason:
              'Generated because both low workload and materially low conversion conditions are supported.',
          urgency: 0.3,
        ));
      }

      final deliveryBranch = deliveryBranches[branch.branchId];
      final deliveryMedian = deliveryBranch?.deliveryPerformance.medianDays;
      if (conversion != null &&
          deliveryMedian != null &&
          networkDeliveryMedian != null &&
          deliveryBranch!.deliveryPerformance.count >=
              config.minimumDeliveries &&
          conversion >= benchmark + 0.05 &&
          deliveryMedian >= networkDeliveryMedian * 1.25) {
        insights.add(_draft(
          id: 'branch.strong_sales_slow_delivery.${_id(branch.branchId)}',
          category: InsightCategory.delivery,
          severity: InsightSeverity.warning,
          title:
              '${branch.branchName} pairs strong conversion with slower delivery',
          finding:
              'Conversion is above network while median delivery time is ${deliveryMedian.toStringAsFixed(1)} days versus ${networkDeliveryMedian.toStringAsFixed(1)} network-wide.',
          significance:
              'Sales strength may be exposed to fulfilment reliability and customer-experience risk.',
          metric: InsightMetric(
            key: 'median_delivery_days',
            label: 'Branch median delivery days',
            value: deliveryMedian,
            unit: MetricUnit.days,
            denominator: deliveryBranch.deliveryPerformance.count,
          ),
          benchmark: InsightBenchmark(
            label: 'Network median delivery days',
            value: networkDeliveryMedian,
            unit: MetricUnit.days,
            method: 'median of linked deliveries',
            sampleSize: deliveryAnalytics.deliveries().overall.count,
          ),
          affected: deliveryDataset.leads
              .where((lead) =>
                  lead.branchId == branch.branchId && lead.isDelivered)
              .toList(),
          affectedValue: deliveryBranch.metrics.deliveredDealValue,
          minimumSupport: config.minimumDeliveries,
          dimensions: InsightDimensions(branchIds: [branch.branchId]),
          investigation:
              'Investigate fulfilment capacity and delay reasons while preserving the branch’s sales practices.',
          reason:
              'Generated because supported sales conversion is strong but delivery duration is at least 25% above network median.',
          urgency: 0.6,
        ));
      }
    }
    return insights;
  }

  List<_DraftInsight> _repInsights(
    AnalyticalDataset dataset,
    DealershipAnalyticsEngine analytics,
  ) {
    final insights = <_DraftInsight>[];
    final reps = analytics.salesReps();
    for (final rep in reps) {
      if (rep.metrics.resolved < config.minimumResolvedLeads ||
          rep.metrics.resolvedConversion == null) {
        continue;
      }
      final branchRecords =
          dataset.leads.where((lead) => lead.branchId == rep.branchId).toList();
      final branch = analytics.businessOverview(branchRecords);
      final benchmark = branch.resolvedConversion;
      if (benchmark == null) continue;
      final difference = rep.metrics.resolvedConversion! - benchmark;
      if (difference.abs() < config.minimumRateDifference) continue;
      final records =
          dataset.leads.where((lead) => lead.repId == rep.repId).toList();
      final positive = difference > 0;
      insights.add(_draft(
        id: 'rep.${positive ? 'above' : 'below'}_branch.${_id(rep.repId)}',
        category: positive
            ? InsightCategory.positiveOpportunity
            : InsightCategory.rep,
        severity: positive ? InsightSeverity.positive : InsightSeverity.warning,
        title: positive
            ? '${rep.repName} shows resilient conversion'
            : '${rep.repName} has a supported coaching signal',
        finding:
            'Resolved conversion is ${_percent(rep.metrics.resolvedConversion!)}, ${positive ? 'above' : 'below'} the ${_percent(benchmark)} branch benchmark.',
        significance: positive
            ? 'The record set may contain practices worth understanding and sharing.'
            : 'A material peer-relative gap identifies where coaching investigation may be useful; it does not establish individual causality.',
        metric: InsightMetric(
          key: 'resolved_conversion',
          label: 'Representative resolved conversion',
          value: rep.metrics.resolvedConversion!,
          unit: MetricUnit.rate,
          numerator: rep.metrics.delivered,
          denominator: rep.metrics.resolved,
        ),
        benchmark: InsightBenchmark(
          label: 'Branch resolved conversion',
          value: benchmark,
          unit: MetricUnit.rate,
          method: 'all resolved branch leads in scope',
          sampleSize: branch.resolvedLeads,
        ),
        affected: records.where((lead) => lead.isResolved).toList(),
        affectedValue: positive
            ? rep.metrics.deliveredDealValue
            : _sumValue(records.where((lead) => lead.isLost).toList()),
        minimumSupport: config.minimumResolvedLeads,
        dimensions:
            InsightDimensions(branchIds: [rep.branchId], repIds: [rep.repId]),
        investigation: positive
            ? 'Review stage handling and follow-up patterns for transferable practices.'
            : 'Review workload, lead mix, stage progression, and follow-up timing in a coaching context.',
        reason:
            'Generated because supported representative conversion differs from the branch benchmark by at least ${_percent(config.minimumRateDifference)}.',
        urgency: positive ? 0.1 : 0.4,
      ));
    }
    return insights;
  }

  List<_DraftInsight> _sourceInsights(
    AnalyticalDataset dataset,
    DealershipAnalyticsEngine analytics,
  ) {
    final insights = <_DraftInsight>[];
    final network = analytics.businessOverview();
    final networkContact = _rate(
      dataset.leads.where((lead) => lead.reachedContacted).length,
      dataset.leads.length,
    );
    final networkPostContact = _rate(
      dataset.leads.where((lead) => lead.reachedTestDrive).length,
      dataset.leads.where((lead) => lead.reachedContacted).length,
    );
    final volumeMedian = _median(
        analytics.sources().map((source) => source.volume.toDouble()).toList());
    final totalActiveValue =
        _sumValue(dataset.leads.where((lead) => lead.isActive).toList())
            .toDouble();
    for (final source in analytics.sources()) {
      final records =
          dataset.leads.where((lead) => lead.source == source.source).toList();
      final label = source.source ?? 'Unattributed source';
      if (source.volume >= config.minimumSegmentLeads &&
          source.contactRate != null &&
          networkContact != null &&
          networkContact - source.contactRate! >=
              config.minimumRateDifference) {
        insights.add(_comparisonDraft(
          id: 'source.low_contact.${_id(label)}',
          category: InsightCategory.source,
          severity: InsightSeverity.warning,
          title: '$label has a low contact rate',
          finding:
              '${_percent(source.contactRate!)} reach contact versus ${_percent(networkContact)} network-wide.',
          significance:
              'The source loses opportunity volume before post-contact quality can be assessed.',
          metricKey: 'contact_rate',
          metricLabel: 'Source contact rate',
          observed: source.contactRate!,
          benchmarkValue: networkContact,
          benchmarkLabel: 'Network contact rate',
          benchmarkSample: dataset.leads.length,
          affected: records.where((lead) => !lead.reachedContacted).toList(),
          affectedValue: _sumValue(
              records.where((lead) => !lead.reachedContacted).toList()),
          dimensions: InsightDimensions(sourceIds: [source.source]),
          investigation:
              'Review attribution, response timing, and handling before drawing conclusions about source quality.',
          reason:
              'Generated because supported source contact rate is materially below the network rate.',
        ));
      }
      final contacted = records.where((lead) => lead.reachedContacted).length;
      if (contacted >= config.minimumStageLeads &&
          source.testDriveAmongContacted != null &&
          networkPostContact != null &&
          networkPostContact - source.testDriveAmongContacted! >=
              config.minimumRateDifference) {
        insights.add(_comparisonDraft(
          id: 'source.low_post_contact.${_id(label)}',
          category: InsightCategory.source,
          severity: InsightSeverity.warning,
          title: '$label weakens after contact',
          finding:
              '${_percent(source.testDriveAmongContacted!)} of contacted leads reach test drive versus ${_percent(networkPostContact)} network-wide.',
          significance:
              'Separating post-contact progression from raw conversion narrows the investigation to later funnel behavior.',
          metricKey: 'test_drive_among_contacted',
          metricLabel: 'Test-drive rate among contacted',
          observed: source.testDriveAmongContacted!,
          benchmarkValue: networkPostContact,
          benchmarkLabel: 'Network contacted-to-test-drive rate',
          benchmarkSample: contacted,
          affected: records
              .where((lead) => lead.reachedContacted && !lead.reachedTestDrive)
              .toList(),
          affectedValue: _sumValue(records
              .where((lead) => lead.reachedContacted && !lead.reachedTestDrive)
              .toList()),
          dimensions: InsightDimensions(sourceIds: [source.source]),
          investigation:
              'Compare lead needs and post-contact handling without assuming either is the cause.',
          reason:
              'Generated because supported contacted-to-test-drive progression is materially below network.',
        ));
      }
      final resolved = records.where((lead) => lead.isResolved).length;
      if (resolved >= config.minimumResolvedLeads &&
          source.resolvedConversion != null &&
          network.resolvedConversion != null &&
          source.resolvedConversion! >=
              network.resolvedConversion! + config.minimumRateDifference &&
          volumeMedian != null &&
          source.volume < volumeMedian) {
        insights.add(_comparisonDraft(
          id: 'source.quality_low_volume.${_id(label)}',
          category: InsightCategory.positiveOpportunity,
          severity: InsightSeverity.opportunity,
          title: '$label converts well at lower volume',
          finding:
              'Resolved conversion is ${_percent(source.resolvedConversion!)} on below-median source volume.',
          significance:
              'The source may warrant a controlled volume-expansion test while monitoring whether performance persists.',
          metricKey: 'resolved_conversion',
          metricLabel: 'Source resolved conversion',
          observed: source.resolvedConversion!,
          benchmarkValue: network.resolvedConversion!,
          benchmarkLabel: 'Network resolved conversion',
          benchmarkSample: network.resolvedLeads,
          affected: records.where((lead) => lead.isResolved).toList(),
          affectedValue: source.deliveredValue,
          dimensions: InsightDimensions(sourceIds: [source.source]),
          investigation:
              'Assess whether additional volume is available and validate performance with a measured expansion.',
          reason:
              'Generated because supported conversion is materially above network while source volume is below the source median.',
          positive: true,
        ));
      }
      final activeShare = totalActiveValue == 0
          ? 0.0
          : source.activeValue.toDouble() / totalActiveValue;
      if (source.volume >= config.minimumSegmentLeads && activeShare >= 0.3) {
        insights.add(_draft(
          id: 'source.active_value_concentration.${_id(label)}',
          category: InsightCategory.source,
          severity: InsightSeverity.opportunity,
          title: '$label holds concentrated active value',
          finding:
              '${_percent(activeShare)} of active opportunity value is associated with this source.',
          significance:
              'Concentrated pipeline value makes source-specific execution materially important.',
          metric: InsightMetric(
            key: 'active_value_share',
            label: 'Share of active opportunity value',
            value: activeShare,
            unit: MetricUnit.rate,
          ),
          benchmark: const InsightBenchmark(
            label: 'Concentration threshold',
            value: 0.3,
            unit: MetricUnit.rate,
            method: 'explicit materiality threshold',
            sampleSize: 0,
          ),
          affected: records.where((lead) => lead.isActive).toList(),
          affectedValue: source.activeValue,
          minimumSupport: config.minimumSegmentLeads,
          dimensions: InsightDimensions(sourceIds: [source.source]),
          investigation:
              'Review the active records and source handling to protect concentrated opportunity value.',
          reason:
              'Generated because the source contains at least 30% of active opportunity value with sufficient volume.',
          urgency: 0.5,
        ));
      }
    }
    return insights;
  }

  List<_DraftInsight> _vehicleInsights(
    AnalyticalDataset dataset,
    DealershipAnalyticsEngine analytics,
  ) {
    final insights = <_DraftInsight>[];
    final network = analytics.businessOverview();
    for (final vehicle in analytics.vehicles()) {
      if (vehicle.leadCount < config.minimumSegmentLeads) continue;
      final records = dataset.leads
          .where((lead) => lead.vehicleModel == vehicle.model)
          .toList();
      final conversion = vehicle.resolvedConversion;
      if (vehicle.deliveredValueShare != null &&
          vehicle.deliveredValueShare! >= 0.2 &&
          conversion != null &&
          network.resolvedConversion != null &&
          network.resolvedConversion! - conversion >=
              config.minimumRateDifference) {
        insights.add(_comparisonDraft(
          id: 'vehicle.high_value_weak_conversion.${_id(vehicle.model)}',
          category: InsightCategory.vehicle,
          severity: InsightSeverity.warning,
          title:
              '${vehicle.model} combines high value importance with weak conversion',
          finding:
              'The model contributes ${_percent(vehicle.deliveredValueShare!)} of delivered value, while resolved conversion trails the network.',
          significance:
              'Improvement around an economically important model may affect more value than its lead count alone suggests.',
          metricKey: 'resolved_conversion',
          metricLabel: 'Model resolved conversion',
          observed: conversion,
          benchmarkValue: network.resolvedConversion!,
          benchmarkLabel: 'Network resolved conversion',
          benchmarkSample: network.resolvedLeads,
          affected: records.where((lead) => lead.isResolved).toList(),
          affectedValue:
              _sumValue(records.where((lead) => lead.isLost).toList()),
          dimensions: InsightDimensions(modelIds: [vehicle.model]),
          investigation:
              'Review loss reasons, availability, pricing discussions, and stage handling without inferring which is causal.',
          reason:
              'Generated because delivered-value share is material and supported conversion is below network.',
        ));
      }
      if (vehicle.leadShare != null &&
          vehicle.deliveredValueShare != null &&
          vehicle.leadShare! >= 0.2 &&
          vehicle.deliveredValueShare! <= vehicle.leadShare! * 0.7) {
        insights.add(_draft(
          id: 'vehicle.demand_value_gap.${_id(vehicle.model)}',
          category: InsightCategory.vehicle,
          severity: InsightSeverity.opportunity,
          title: '${vehicle.model} demand exceeds delivered-value contribution',
          finding:
              'The model represents ${_percent(vehicle.leadShare!)} of leads but ${_percent(vehicle.deliveredValueShare!)} of delivered value.',
          significance:
              'High interest is not translating into a proportional share of delivered deal value.',
          metric: InsightMetric(
            key: 'delivered_value_share',
            label: 'Delivered-value share',
            value: vehicle.deliveredValueShare!,
            unit: MetricUnit.rate,
          ),
          benchmark: InsightBenchmark(
            label: 'Lead-volume share',
            value: vehicle.leadShare!,
            unit: MetricUnit.rate,
            method: 'model share of scoped leads',
            sampleSize: dataset.leads.length,
          ),
          affected: records,
          affectedValue: vehicle.activeOpportunityValue,
          minimumSupport: config.minimumSegmentLeads,
          dimensions: InsightDimensions(modelIds: [vehicle.model]),
          investigation:
              'Examine deal-value mix, stage losses, and availability for this high-demand model.',
          reason:
              'Generated because lead share is material and delivered-value share is at least 30% lower proportionally.',
          urgency: 0.3,
        ));
      }
      if (vehicle.economicImportanceIndex != null &&
          vehicle.economicImportanceIndex! >= 1.3 &&
          vehicle.deliveredCount >= config.minimumResolvedLeads) {
        insights.add(_draft(
          id: 'vehicle.economic_importance.${_id(vehicle.model)}',
          category: InsightCategory.positiveOpportunity,
          severity: InsightSeverity.positive,
          title: '${vehicle.model} has outsized delivered-value importance',
          finding:
              'Delivered-value share is ${vehicle.economicImportanceIndex!.toStringAsFixed(2)} times its lead-volume share.',
          significance:
              'The model contributes more delivered value than its demand share would imply; this is not a margin measure.',
          metric: InsightMetric(
            key: 'economic_importance_index',
            label: 'Economic importance index',
            value: vehicle.economicImportanceIndex!,
            unit: MetricUnit.ratio,
          ),
          benchmark: const InsightBenchmark(
            label: 'Proportional contribution',
            value: 1,
            unit: MetricUnit.ratio,
            method: 'delivered-value share / lead share',
            sampleSize: 0,
          ),
          affected: records.where((lead) => lead.isDelivered).toList(),
          affectedValue: vehicle.deliveredValue,
          minimumSupport: config.minimumResolvedLeads,
          dimensions: InsightDimensions(modelIds: [vehicle.model]),
          investigation:
              'Protect availability and sales capability around the model while validating future mix changes.',
          reason:
              'Generated because the supported economic-importance index is at least 1.30.',
          urgency: 0.1,
        ));
      }
      final lost = records.where((lead) => lead.isLost).toList();
      final reasonGroups = <String?, List<AnalyticalLead>>{};
      for (final lead in lost) {
        reasonGroups.putIfAbsent(lead.lead.lostReason, () => []).add(lead);
      }
      if (lost.length >= config.minimumResolvedLeads &&
          reasonGroups.isNotEmpty) {
        final largest = reasonGroups.entries.reduce((left, right) =>
            left.value.length >= right.value.length ? left : right);
        final share = largest.value.length / lost.length;
        if (share >= 0.5) {
          final reason = largest.key ?? 'unrecorded reason';
          insights.add(_draft(
            id: 'vehicle.concentrated_loss_reason.${_id(vehicle.model)}.${_id(reason)}',
            category: InsightCategory.vehicle,
            severity: InsightSeverity.opportunity,
            title: '${vehicle.model} losses concentrate in one reason',
            finding: '${_percent(share)} of model losses cite $reason.',
            significance:
                'A concentrated recorded reason provides a focused question for model-specific investigation.',
            metric: InsightMetric(
              key: 'top_loss_reason_share',
              label: 'Share of model losses',
              value: share,
              unit: MetricUnit.rate,
              numerator: largest.value.length,
              denominator: lost.length,
            ),
            benchmark: const InsightBenchmark(
              label: 'Concentration threshold',
              value: 0.5,
              unit: MetricUnit.rate,
              method: 'explicit concentration threshold',
              sampleSize: 0,
            ),
            affected: largest.value,
            affectedValue: _sumValue(largest.value),
            minimumSupport: config.minimumResolvedLeads,
            dimensions: InsightDimensions(modelIds: [vehicle.model]),
            investigation:
                'Review the original loss notes and related journey stages before choosing an intervention.',
            reason:
                'Generated because one original loss reason represents at least half of sufficiently supported model losses.',
            urgency: 0.3,
          ));
        }
      }
    }
    return insights;
  }

  List<_DraftInsight> _pipelineInsights(
    AnalyticalDataset dataset,
    DealershipAnalyticsEngine analytics,
  ) {
    final active = dataset.leads.where((lead) => lead.isActive).toList();
    if (active.isEmpty) return const [];
    final insights = <_DraftInsight>[];
    final stale = active
        .where((lead) => lead.daysSinceLastActivity >= config.staleDays)
        .toList();
    final staleShare = stale.length / active.length;
    if (stale.length >= config.minimumStageLeads && staleShare >= 0.2) {
      insights.add(_draft(
        id: 'pipeline.stale_active',
        category: InsightCategory.pipeline,
        severity: staleShare >= 0.5
            ? InsightSeverity.critical
            : InsightSeverity.warning,
        title: 'A material share of active opportunities is stale',
        finding:
            '${stale.length} active opportunities (${_percent(staleShare)}) have no activity for at least ${config.staleDays} days.',
        significance:
            'Stale records represent unattended opportunity value or records needing status confirmation; they are not assumed lost.',
        metric: InsightMetric(
          key: 'stale_active_share',
          label: 'Stale share of active pipeline',
          value: staleShare,
          unit: MetricUnit.rate,
          numerator: stale.length,
          denominator: active.length,
        ),
        benchmark: const InsightBenchmark(
          label: 'Material share threshold',
          value: 0.2,
          unit: MetricUnit.rate,
          method: 'explicit pipeline attention threshold',
          sampleSize: 0,
        ),
        affected: stale,
        affectedValue: _sumValue(stale),
        minimumSupport: config.minimumStageLeads,
        investigation:
            'Prioritize record review by inactivity, expected-close slippage, and deal value.',
        reason:
            'Generated because stale active records exceed both minimum count and pipeline-share thresholds.',
        urgency: 0.9,
      ));
    }
    final overdueOrders = active
        .where((lead) =>
            lead.currentFunnelStage == FunnelStage.orderPlaced &&
            lead.expectedCloseOverdue)
        .toList();
    if (overdueOrders.length >= math.max(3, config.minimumStageLeads ~/ 2)) {
      insights.add(_draft(
        id: 'pipeline.overdue_orders',
        category: InsightCategory.pipeline,
        severity: InsightSeverity.critical,
        title: 'Order-stage opportunities are past expected close',
        finding:
            '${overdueOrders.length} active orders are past expected close as of ${dataset.context.snapshotDate.toIso8601String().substring(0, 10)}.',
        significance:
            'Late order-stage opportunities concentrate near-close value and require timely status confirmation.',
        metric: InsightMetric(
          key: 'overdue_order_count',
          label: 'Overdue order-stage opportunities',
          value: overdueOrders.length.toDouble(),
          unit: MetricUnit.count,
        ),
        benchmark: const InsightBenchmark(
          label: 'Expected overdue count',
          value: 0,
          unit: MetricUnit.count,
          method: 'operational expectation',
          sampleSize: 0,
        ),
        affected: overdueOrders,
        affectedValue: _sumValue(overdueOrders),
        minimumSupport: math.max(3, config.minimumStageLeads ~/ 2),
        investigation:
            'Confirm fulfilment status, expected dates, and whether each record remains active.',
        reason:
            'Generated because multiple active order-stage records are past expected close.',
        urgency: 1,
      ));
    }
    final hygiene = active
        .where((lead) => lead.daysSinceLastActivity >= config.crmHygieneDays)
        .toList();
    if (hygiene.length >= 3) {
      insights.add(_draft(
        id: 'pipeline.crm_hygiene',
        category: InsightCategory.dataQuality,
        severity: InsightSeverity.warning,
        title: 'Extremely old active records may need status verification',
        finding:
            '${hygiene.length} active records have no activity for at least ${config.crmHygieneDays} days.',
        significance:
            'The records may represent genuine long cycles or CRM status hygiene issues; the data cannot distinguish them.',
        metric: InsightMetric(
          key: 'extremely_stale_active_count',
          label: 'Extremely stale active records',
          value: hygiene.length.toDouble(),
          unit: MetricUnit.count,
        ),
        benchmark: InsightBenchmark(
          label: 'CRM hygiene threshold',
          value: config.crmHygieneDays.toDouble(),
          unit: MetricUnit.days,
          method: 'configurable inactivity threshold',
          sampleSize: active.length,
        ),
        affected: hygiene,
        affectedValue: _sumValue(hygiene),
        minimumSupport: 3,
        investigation:
            'Verify current status and expected-close dates without automatically marking the records lost.',
        reason:
            'Generated because at least three active records exceed the extreme inactivity threshold.',
        urgency: 0.8,
      ));
    }
    return insights;
  }

  List<_DraftInsight> _deliveryInsights(
    AnalyticalDataset dataset,
    DealershipAnalyticsEngine analytics,
  ) {
    final result = analytics.deliveries();
    final insights = <_DraftInsight>[];
    for (final reason in result.delayReasons) {
      final increment = reason.incrementalAverageDays;
      if (reason.stats.count < config.minimumDeliveries ||
          increment == null ||
          increment < config.minimumDelayDaysDifference) {
        continue;
      }
      final deliveries = dataset.source.deliveries
          .where((delivery) => delivery.delayReason == reason.reason)
          .toList();
      final ids = deliveries.map((delivery) => delivery.leadId).toSet();
      final records =
          dataset.leads.where((lead) => ids.contains(lead.id)).toList();
      insights.add(_draft(
        id: 'delivery.delay_reason.${_id(reason.reason)}',
        category: InsightCategory.delivery,
        severity: increment >= config.minimumDelayDaysDifference * 2
            ? InsightSeverity.critical
            : InsightSeverity.warning,
        title: '${reason.reason} is associated with longer fulfilment',
        finding:
            'Average delivery duration is ${increment.toStringAsFixed(1)} days longer than deliveries without a recorded delay reason.',
        significance:
            'The association identifies a material fulfilment category for investigation but does not prove causality.',
        metric: InsightMetric(
          key: 'average_delivery_days',
          label: '${reason.reason} average delivery days',
          value: reason.stats.averageDays!,
          unit: MetricUnit.days,
          denominator: reason.stats.count,
        ),
        benchmark: InsightBenchmark(
          label: 'No recorded delay average',
          value: result.withoutRecordedDelay.averageDays!,
          unit: MetricUnit.days,
          method: 'deliveries with null delay_reason',
          sampleSize: result.withoutRecordedDelay.count,
        ),
        affected: records,
        affectedValue: _sumValue(records),
        minimumSupport: config.minimumDeliveries,
        investigation:
            'Review the linked delivery records and operational process associated with this reason.',
        reason:
            'Generated because the category has sufficient deliveries and exceeds the no-recorded-delay baseline by the configured number of days.',
        urgency: 0.7,
      ));
    }
    final networkMedian = result.overall.medianDays;
    if (networkMedian != null) {
      for (final branch in analytics.branches()) {
        final stats = branch.deliveryPerformance;
        if (stats.count < config.minimumDeliveries ||
            stats.medianDays == null) {
          continue;
        }
        final relative = networkMedian == 0
            ? 0.0
            : (stats.medianDays! - networkMedian) / networkMedian;
        if (relative < config.minimumRelativeDifference) continue;
        final records = dataset.leads
            .where(
                (lead) => lead.branchId == branch.branchId && lead.isDelivered)
            .toList();
        insights.add(_draft(
          id: 'delivery.branch_outlier.${_id(branch.branchId)}',
          category: InsightCategory.delivery,
          severity: relative >= 0.5
              ? InsightSeverity.critical
              : InsightSeverity.warning,
          title: '${branch.branchName} has slower delivery duration',
          finding:
              'Median delivery time is ${stats.medianDays!.toStringAsFixed(1)} days, ${_percent(relative)} above the network median.',
          significance:
              'A supported branch-level fulfilment gap may affect delivered-value reliability and customer experience.',
          metric: InsightMetric(
            key: 'median_delivery_days',
            label: 'Branch median delivery days',
            value: stats.medianDays!,
            unit: MetricUnit.days,
            denominator: stats.count,
          ),
          benchmark: InsightBenchmark(
            label: 'Network median delivery days',
            value: networkMedian,
            unit: MetricUnit.days,
            method: 'median of linked deliveries',
            sampleSize: result.overall.count,
          ),
          affected: records,
          affectedValue: branch.metrics.deliveredDealValue,
          minimumSupport: config.minimumDeliveries,
          dimensions: InsightDimensions(branchIds: [branch.branchId]),
          investigation:
              'Compare delay-reason mix, vehicle mix, and fulfilment workflow with other branches.',
          reason:
              'Generated because supported branch median delivery duration exceeds network median by the configured relative difference.',
          urgency: 0.6,
        ));
      }
    }
    return insights;
  }

  List<_DraftInsight> _dataQualityInsights(
    AnalyticalDataset dataset,
    ValidationReport? report,
  ) {
    if (report == null) return const [];
    final grouped = <ValidationCode, List<ValidationIssue>>{};
    for (final issue in report.issues.where((issue) =>
        issue.recordId != null && issue.severity != ValidationSeverity.fatal)) {
      grouped.putIfAbsent(issue.code, () => []).add(issue);
    }
    final byId = {for (final lead in dataset.leads) lead.id: lead};
    return grouped.entries.map((entry) {
      final records = entry.value
          .map((issue) => byId[issue.recordId])
          .whereType<AnalyticalLead>()
          .toList();
      return _draft(
        id: 'data_quality.${entry.key.name}',
        category: InsightCategory.dataQuality,
        severity: entry.value
                .any((issue) => issue.severity == ValidationSeverity.error)
            ? InsightSeverity.critical
            : InsightSeverity.informational,
        title: '${entry.value.length} records have ${_codeName(entry.key)}',
        finding:
            'Validation identified ${entry.value.length} affected records; source values were preserved without repair.',
        significance:
            'The inconsistency can qualify metrics that depend on these fields or event histories.',
        metric: InsightMetric(
          key: 'validation_issue_count',
          label: 'Affected records',
          value: entry.value.length.toDouble(),
          unit: MetricUnit.count,
        ),
        benchmark: const InsightBenchmark(
          label: 'Expected validation issues',
          value: 0,
          unit: MetricUnit.count,
          method: 'canonical data-quality expectation',
          sampleSize: 0,
        ),
        affected: records,
        affectedValue: _sumValue(records),
        minimumSupport: 1,
        investigation:
            'Review the exact source records and decide an explicit analytical inclusion policy; do not mutate them silently.',
        reason:
            'Generated directly from structured ${entry.key.name} validation findings.',
        urgency: entry.value
                .any((issue) => issue.severity == ValidationSeverity.error)
            ? 0.9
            : 0.3,
      );
    }).toList(growable: false);
  }

  _DraftInsight _comparisonDraft({
    required String id,
    required InsightCategory category,
    required InsightSeverity severity,
    required String title,
    required String finding,
    required String significance,
    required String metricKey,
    required String metricLabel,
    required double observed,
    required double benchmarkValue,
    required String benchmarkLabel,
    required int benchmarkSample,
    required List<AnalyticalLead> affected,
    required num affectedValue,
    required InsightDimensions dimensions,
    required String investigation,
    required String reason,
    bool positive = false,
  }) =>
      _draft(
        id: id,
        category: category,
        severity: severity,
        title: title,
        finding: finding,
        significance: significance,
        metric: InsightMetric(
          key: metricKey,
          label: metricLabel,
          value: observed,
          unit: MetricUnit.rate,
        ),
        benchmark: InsightBenchmark(
          label: benchmarkLabel,
          value: benchmarkValue,
          unit: MetricUnit.rate,
          method: 'scope-wide weighted benchmark',
          sampleSize: benchmarkSample,
        ),
        affected: affected,
        affectedValue: affectedValue,
        minimumSupport:
            positive ? config.minimumResolvedLeads : config.minimumSegmentLeads,
        dimensions: dimensions,
        investigation: investigation,
        reason: reason,
        urgency: positive ? 0.1 : 0.5,
      );

  _DraftInsight _draft({
    required String id,
    required InsightCategory category,
    required InsightSeverity severity,
    required String title,
    required String finding,
    required String significance,
    required InsightMetric metric,
    required InsightBenchmark? benchmark,
    required List<AnalyticalLead> affected,
    required num? affectedValue,
    required int minimumSupport,
    required String investigation,
    required String reason,
    required double urgency,
    InsightDimensions? dimensions,
  }) {
    final absolute = benchmark == null ? null : metric.value - benchmark.value;
    final relative = benchmark == null || benchmark.value == 0
        ? null
        : absolute! / benchmark.value.abs();
    return _DraftInsight(
      id: id,
      category: category,
      severity: severity,
      title: title,
      finding: finding,
      businessSignificance: significance,
      observedMetric: metric,
      benchmark: benchmark,
      absoluteDifference: absolute,
      relativeDifference: relative,
      affectedLeadIds: affected.map((lead) => lead.id).toList(),
      affectedDealValue: affectedValue,
      evidenceStrength: _evidence(affected.length, minimumSupport),
      dimensions: dimensions ?? InsightDimensions(),
      suggestedInvestigation: investigation,
      generationReason: reason,
      urgency: urgency,
    );
  }

  ManagementInsight _rank(_DraftInsight draft, double totalValue) {
    final severity = switch (draft.severity) {
      InsightSeverity.critical => 5.0,
      InsightSeverity.warning => 4.0,
      InsightSeverity.opportunity => 3.0,
      InsightSeverity.positive => 2.5,
      InsightSeverity.informational => 2.0,
    };
    final deviation = math.min(
      20.0,
      (draft.relativeDifference?.abs() ??
              draft.absoluteDifference?.abs() ??
              0) *
          25,
    );
    final records = draft.affectedLeadIds.isEmpty
        ? 0.0
        : math.min(
            15.0, math.log(draft.affectedLeadIds.length + 1) / math.ln10 * 7);
    final valueShare = totalValue <= 0 || draft.affectedDealValue == null
        ? 0.0
        : math.min(15.0, draft.affectedDealValue!.toDouble() / totalValue * 30);
    final evidence = switch (draft.evidenceStrength) {
      EvidenceStrength.strong => 8.0,
      EvidenceStrength.moderate => 4.0,
      EvidenceStrength.weak => 0.0,
    };
    final urgency = draft.urgency * 10;
    final factors = {
      'severity': severity * 20,
      'deviation': deviation,
      'affected_records': records,
      'affected_value': valueShare,
      'evidence': evidence,
      'urgency': urgency,
    };
    final score = factors.values.fold<double>(0, (sum, value) => sum + value);
    return ManagementInsight(
      id: draft.id,
      category: draft.category,
      severity: draft.severity,
      title: draft.title,
      finding: draft.finding,
      businessSignificance: draft.businessSignificance,
      observedMetric: draft.observedMetric,
      benchmark: draft.benchmark,
      absoluteDifference: draft.absoluteDifference,
      relativeDifference: draft.relativeDifference,
      affectedLeadCount: draft.affectedLeadIds.length,
      affectedDealValue: draft.affectedDealValue,
      evidenceStrength: draft.evidenceStrength,
      dimensions: draft.dimensions,
      affectedLeadIds: draft.affectedLeadIds,
      suggestedInvestigation: draft.suggestedInvestigation,
      generationReason: draft.generationReason,
      rankScore: score,
      rankingFactors: factors,
    );
  }

  EvidenceStrength _evidence(int sample, int minimum) {
    if (sample >= minimum * 3) return EvidenceStrength.strong;
    if (sample >= minimum) return EvidenceStrength.moderate;
    return EvidenceStrength.weak;
  }

  static double? _rate(num numerator, num denominator) =>
      denominator == 0 ? null : numerator / denominator;

  static num _sumValue(Iterable<AnalyticalLead> leads) =>
      leads.fold<num>(0, (sum, lead) => sum + lead.dealValue);

  static double? _median(List<double> values) => _percentile(values, 0.5);

  static double? _percentile(List<double> values, double percentile) {
    if (values.isEmpty) return null;
    final sorted = [...values]..sort();
    if (sorted.length == 1) return sorted.single;
    final position = percentile * (sorted.length - 1);
    final lower = position.floor();
    final upper = position.ceil();
    return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - lower);
  }

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

  static String _stageName(FunnelStage stage) => switch (stage) {
        FunnelStage.newLead => 'new',
        FunnelStage.contacted => 'contacted',
        FunnelStage.testDrive => 'test drive',
        FunnelStage.negotiation => 'negotiation',
        FunnelStage.orderPlaced => 'order placed',
        FunnelStage.delivered => 'delivered',
      };

  static String _percent(double value) =>
      '${(value * 100).toStringAsFixed(1)}%';

  static String _id(String value) => Uri.encodeComponent(value);

  static String _ruleFamily(String id) {
    final parts = id.split('.');
    return parts.length < 2 ? id : '${parts[0]}.${parts[1]}';
  }

  static String _dimensionSignature(ManagementInsight insight) => [
        insight.category.name,
        ...insight.dimensions.branchIds,
        ...insight.dimensions.repIds,
        ...insight.dimensions.sourceIds.map((value) => value ?? '<null>'),
        ...insight.dimensions.modelIds,
      ].join('|');

  static String _codeName(ValidationCode code) =>
      code.name.replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match[1]}');
}

final class _DraftInsight {
  const _DraftInsight({
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
    required this.affectedLeadIds,
    required this.affectedDealValue,
    required this.evidenceStrength,
    required this.dimensions,
    required this.suggestedInvestigation,
    required this.generationReason,
    required this.urgency,
  });

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
  final List<String> affectedLeadIds;
  final num? affectedDealValue;
  final EvidenceStrength evidenceStrength;
  final InsightDimensions dimensions;
  final String suggestedInvestigation;
  final String generationReason;
  final double urgency;
}
