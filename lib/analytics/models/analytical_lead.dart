import 'dart:collection';

import '../../data/models/dealership_models.dart';

enum FunnelStage {
  newLead,
  contacted,
  testDrive,
  negotiation,
  orderPlaced,
  delivered,
}

extension FunnelStageOrder on FunnelStage {
  int get order => index;
}

final class AnalyticsContext {
  const AnalyticsContext({
    required this.snapshotDate,
    required this.maturityDuration,
    this.maturityPercentile = 0.8,
  });

  final DateTime snapshotDate;
  final Duration? maturityDuration;
  final double maturityPercentile;
}

final class AnalyticalLead {
  const AnalyticalLead({
    required this.lead,
    required this.context,
    required this.reachedContacted,
    required this.reachedTestDrive,
    required this.reachedNegotiation,
    required this.reachedOrderPlaced,
    required this.reachedDelivered,
    required this.contactedAt,
    required this.testDriveAt,
    required this.negotiationAt,
    required this.orderPlacedAt,
    required this.deliveredAt,
    required this.newToContacted,
    required this.contactedToTestDrive,
    required this.testDriveToNegotiation,
    required this.negotiationToOrder,
    required this.orderToDelivery,
    required this.creationToDelivery,
    required this.currentFunnelStage,
    required this.highestSuccessfulStage,
    required this.currentStageEnteredAt,
    required this.daysInCurrentStage,
    required this.daysSinceLastActivity,
    required this.isActive,
    required this.isResolved,
    required this.isDelivered,
    required this.isLost,
    required this.lostAt,
    required this.lostFromStage,
    required this.expectedCloseOverdue,
    required this.expectedCloseSlippage,
    required this.repTenureAtCreation,
    required this.isMatureForOutcomeComparison,
    required this.hasValidChronology,
  });

  final Lead lead;
  final AnalyticsContext context;
  final bool reachedContacted;
  final bool reachedTestDrive;
  final bool reachedNegotiation;
  final bool reachedOrderPlaced;
  final bool reachedDelivered;
  final DateTime? contactedAt;
  final DateTime? testDriveAt;
  final DateTime? negotiationAt;
  final DateTime? orderPlacedAt;
  final DateTime? deliveredAt;
  final Duration? newToContacted;
  final Duration? contactedToTestDrive;
  final Duration? testDriveToNegotiation;
  final Duration? negotiationToOrder;
  final Duration? orderToDelivery;
  final Duration? creationToDelivery;
  final FunnelStage? currentFunnelStage;
  final FunnelStage? highestSuccessfulStage;
  final DateTime? currentStageEnteredAt;
  final int? daysInCurrentStage;
  final int daysSinceLastActivity;
  final bool isActive;
  final bool isResolved;
  final bool isDelivered;
  final bool isLost;
  final DateTime? lostAt;
  final FunnelStage? lostFromStage;
  final bool expectedCloseOverdue;
  final Duration? expectedCloseSlippage;
  final Duration? repTenureAtCreation;
  final bool isMatureForOutcomeComparison;
  final bool hasValidChronology;

  String get id => lead.id;
  String get branchId => lead.branchId;
  String get repId => lead.assignedTo;
  String? get source => lead.source;
  String get vehicleModel => lead.modelInterested;
  num get dealValue => lead.dealValue;
}

final class AnalyticalDataset {
  AnalyticalDataset({
    required this.source,
    required this.context,
    required List<AnalyticalLead> leads,
  }) : leads = UnmodifiableListView(leads);

  final DealershipDataset source;
  final AnalyticsContext context;
  final List<AnalyticalLead> leads;
}
