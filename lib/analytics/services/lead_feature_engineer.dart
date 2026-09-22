import '../../data/models/dealership_models.dart';
import '../models/analytical_lead.dart';

final class LeadFeatureEngineer {
  const LeadFeatureEngineer({this.maturityPercentile = 0.8})
      : assert(maturityPercentile >= 0 && maturityPercentile <= 1);

  final double maturityPercentile;

  AnalyticalDataset build(
    DealershipDataset dataset, {
    DateTime? snapshotDate,
  }) {
    final snapshot = snapshotDate ?? _defaultSnapshot(dataset);
    final maturity = _maturityDuration(dataset);
    final context = AnalyticsContext(
      snapshotDate: snapshot,
      maturityDuration: maturity,
      maturityPercentile: maturityPercentile,
    );
    final reps = {for (final rep in dataset.salesReps) rep.id: rep};
    return AnalyticalDataset(
      source: dataset,
      context: context,
      leads: dataset.leads
          .map((lead) => _derive(lead, reps[lead.assignedTo], context))
          .toList(),
    );
  }

  DateTime _defaultSnapshot(DealershipDataset dataset) {
    final timestamps = <DateTime>[];
    for (final lead in dataset.leads) {
      timestamps
        ..add(lead.createdAt)
        ..add(lead.lastActivityAt)
        ..addAll(lead.statusHistory.map((entry) => entry.timestamp));
    }
    for (final delivery in dataset.deliveries) {
      timestamps
        ..add(delivery.orderDate)
        ..add(delivery.deliveryDate);
    }
    if (timestamps.isEmpty) return dataset.metadata.generatedAt;
    return timestamps
        .reduce((left, right) => left.isAfter(right) ? left : right);
  }

  Duration? _maturityDuration(DealershipDataset dataset) {
    final completedDurations = <Duration>[];
    for (final lead in dataset.leads) {
      final deliveredAt = _firstTimestamp(lead, LeadStatus.delivered);
      final duration = _nonNegativeDifference(deliveredAt, lead.createdAt);
      if (duration != null) completedDurations.add(duration);
    }
    return _durationPercentile(completedDurations, maturityPercentile);
  }

  AnalyticalLead _derive(
    Lead lead,
    SalesRep? rep,
    AnalyticsContext context,
  ) {
    final newAt = _firstTimestamp(lead, LeadStatus.newLead) ?? lead.createdAt;
    final contactedAt = _firstTimestamp(lead, LeadStatus.contacted);
    final testDriveAt = _firstTimestamp(lead, LeadStatus.testDrive);
    final negotiationAt = _firstTimestamp(lead, LeadStatus.negotiation);
    final orderPlacedAt = _firstTimestamp(lead, LeadStatus.orderPlaced);
    final deliveredAt = _firstTimestamp(lead, LeadStatus.delivered);
    final lostAt = _firstTimestamp(lead, LeadStatus.lost);
    final stageTimes = <FunnelStage, DateTime>{
      FunnelStage.newLead: newAt,
      if (contactedAt != null) FunnelStage.contacted: contactedAt,
      if (testDriveAt != null) FunnelStage.testDrive: testDriveAt,
      if (negotiationAt != null) FunnelStage.negotiation: negotiationAt,
      if (orderPlacedAt != null) FunnelStage.orderPlaced: orderPlacedAt,
      if (deliveredAt != null) FunnelStage.delivered: deliveredAt,
    };
    final highestStage = stageTimes.keys.reduce(
      (left, right) => left.order > right.order ? left : right,
    );
    final isDelivered = lead.status.value == LeadStatus.delivered;
    final isLost = lead.status.value == LeadStatus.lost;
    final isResolved = isDelivered || isLost;
    final isActive = lead.status.isKnown && !isResolved;
    final currentStage = _currentStage(lead.status.value, highestStage);
    final stageEnteredAt =
        currentStage == null ? null : stageTimes[currentStage];
    final stageEnd = isLost && lostAt != null ? lostAt : context.snapshotDate;
    final maturity = context.maturityDuration;

    return AnalyticalLead(
      lead: lead,
      context: context,
      reachedContacted: contactedAt != null,
      reachedTestDrive: testDriveAt != null,
      reachedNegotiation: negotiationAt != null,
      reachedOrderPlaced: orderPlacedAt != null,
      reachedDelivered: deliveredAt != null,
      contactedAt: contactedAt,
      testDriveAt: testDriveAt,
      negotiationAt: negotiationAt,
      orderPlacedAt: orderPlacedAt,
      deliveredAt: deliveredAt,
      newToContacted: _nonNegativeDifference(contactedAt, newAt),
      contactedToTestDrive: _nonNegativeDifference(testDriveAt, contactedAt),
      testDriveToNegotiation:
          _nonNegativeDifference(negotiationAt, testDriveAt),
      negotiationToOrder: _nonNegativeDifference(orderPlacedAt, negotiationAt),
      orderToDelivery: _nonNegativeDifference(deliveredAt, orderPlacedAt),
      creationToDelivery: _nonNegativeDifference(deliveredAt, lead.createdAt),
      currentFunnelStage: currentStage,
      highestSuccessfulStage: highestStage,
      currentStageEnteredAt: stageEnteredAt,
      daysInCurrentStage:
          _nonNegativeDifference(stageEnd, stageEnteredAt)?.inDays,
      daysSinceLastActivity:
          _nonNegativeDifference(context.snapshotDate, lead.lastActivityAt)
                  ?.inDays ??
              0,
      isActive: isActive,
      isResolved: isResolved,
      isDelivered: isDelivered,
      isLost: isLost,
      lostAt: lostAt,
      lostFromStage: isLost ? highestStage : null,
      expectedCloseOverdue:
          isActive && context.snapshotDate.isAfter(lead.expectedCloseDate),
      expectedCloseSlippage: isActive
          ? _nonNegativeDifference(context.snapshotDate, lead.expectedCloseDate)
          : null,
      repTenureAtCreation: rep == null
          ? null
          : _nonNegativeDifference(lead.createdAt, rep.joined),
      isMatureForOutcomeComparison: maturity != null &&
          !lead.createdAt.add(maturity).isAfter(context.snapshotDate),
      hasValidChronology: _hasValidChronology(lead),
    );
  }

  FunnelStage? _currentStage(LeadStatus status, FunnelStage highest) =>
      switch (status) {
        LeadStatus.newLead => FunnelStage.newLead,
        LeadStatus.contacted => FunnelStage.contacted,
        LeadStatus.testDrive => FunnelStage.testDrive,
        LeadStatus.negotiation => FunnelStage.negotiation,
        LeadStatus.orderPlaced => FunnelStage.orderPlaced,
        LeadStatus.delivered => FunnelStage.delivered,
        LeadStatus.lost => highest,
        LeadStatus.unknown => null,
      };

  bool _hasValidChronology(Lead lead) {
    for (var index = 1; index < lead.statusHistory.length; index++) {
      if (lead.statusHistory[index].timestamp
          .isBefore(lead.statusHistory[index - 1].timestamp)) {
        return false;
      }
    }
    return true;
  }

  static DateTime? _firstTimestamp(Lead lead, LeadStatus status) {
    final timestamps = lead.statusHistory
        .where((entry) => entry.status.value == status)
        .map((entry) => entry.timestamp);
    if (timestamps.isEmpty) return null;
    return timestamps
        .reduce((left, right) => left.isBefore(right) ? left : right);
  }

  static Duration? _nonNegativeDifference(DateTime? end, DateTime? start) {
    if (end == null || start == null || end.isBefore(start)) return null;
    return end.difference(start);
  }

  static Duration? _durationPercentile(
    List<Duration> values,
    double percentile,
  ) {
    if (values.isEmpty) return null;
    final sorted = values.map((value) => value.inMicroseconds).toList()..sort();
    if (sorted.length == 1) return Duration(microseconds: sorted.single);
    final position = percentile * (sorted.length - 1);
    final lower = position.floor();
    final upper = position.ceil();
    final fraction = position - lower;
    final interpolated =
        sorted[lower] + ((sorted[upper] - sorted[lower]) * fraction).round();
    return Duration(microseconds: interpolated);
  }
}
