import 'dart:collection';

enum LeadStatus {
  newLead,
  contacted,
  testDrive,
  negotiation,
  orderPlaced,
  delivered,
  lost,
  unknown,
}

enum SalesRepRole { branchManager, salesOfficer, unknown }

/// A closed-vocabulary value that retains an unrecognized source value.
final class LeadStatusValue {
  const LeadStatusValue(this.value, this.rawValue);

  final LeadStatus value;
  final String rawValue;

  bool get isKnown => value != LeadStatus.unknown;
  bool get isResolved =>
      value == LeadStatus.delivered || value == LeadStatus.lost;

  static LeadStatusValue fromRaw(String raw) => LeadStatusValue(
        switch (raw) {
          'new' => LeadStatus.newLead,
          'contacted' => LeadStatus.contacted,
          'test_drive' => LeadStatus.testDrive,
          'negotiation' => LeadStatus.negotiation,
          'order_placed' => LeadStatus.orderPlaced,
          'delivered' => LeadStatus.delivered,
          'lost' => LeadStatus.lost,
          _ => LeadStatus.unknown,
        },
        raw,
      );

  @override
  bool operator ==(Object other) =>
      other is LeadStatusValue &&
      other.value == value &&
      other.rawValue == rawValue;

  @override
  int get hashCode => Object.hash(value, rawValue);
}

final class SalesRepRoleValue {
  const SalesRepRoleValue(this.value, this.rawValue);

  final SalesRepRole value;
  final String rawValue;

  bool get isKnown => value != SalesRepRole.unknown;

  static SalesRepRoleValue fromRaw(String raw) => SalesRepRoleValue(
        switch (raw) {
          'branch_manager' => SalesRepRole.branchManager,
          'sales_officer' => SalesRepRole.salesOfficer,
          _ => SalesRepRole.unknown,
        },
        raw,
      );
}

final class DealershipMetadata {
  const DealershipMetadata({
    required this.generatedAt,
    required this.description,
    required this.dateRange,
    required this.notes,
  });

  final DateTime generatedAt;
  final String description;
  final String dateRange;
  final String notes;
}

final class Branch {
  const Branch({required this.id, required this.name, required this.city});

  final String id;
  final String name;
  final String city;
}

final class SalesRep {
  const SalesRep({
    required this.id,
    required this.name,
    required this.branchId,
    required this.role,
    required this.joined,
  });

  final String id;
  final String name;
  final String branchId;
  final SalesRepRoleValue role;
  final DateTime joined;
}

final class LeadStatusHistoryEntry {
  const LeadStatusHistoryEntry({
    required this.status,
    required this.timestamp,
    required this.note,
  });

  final LeadStatusValue status;
  final DateTime timestamp;
  final String? note;
}

final class Lead {
  Lead({
    required this.id,
    required this.customerName,
    required this.phone,
    required this.source,
    required this.modelInterested,
    required this.status,
    required this.assignedTo,
    required this.branchId,
    required this.createdAt,
    required this.lastActivityAt,
    required List<LeadStatusHistoryEntry> statusHistory,
    required this.expectedCloseDate,
    required this.dealValue,
    required this.lostReason,
  }) : statusHistory = UnmodifiableListView(statusHistory);

  final String id;
  final String customerName;
  final String phone;
  final String? source;
  final String modelInterested;
  final LeadStatusValue status;
  final String assignedTo;
  final String branchId;
  final DateTime createdAt;
  final DateTime lastActivityAt;
  final List<LeadStatusHistoryEntry> statusHistory;
  final DateTime expectedCloseDate;
  final num dealValue;
  final String? lostReason;
}

final class Target {
  const Target({
    required this.branchId,
    required this.month,
    required this.targetUnits,
    required this.targetRevenue,
  });

  final String branchId;
  final DateTime month;
  final int targetUnits;
  final num targetRevenue;
}

final class Delivery {
  const Delivery({
    required this.leadId,
    required this.orderDate,
    required this.deliveryDate,
    required this.daysToDeliver,
    required this.delayReason,
  });

  final String leadId;
  final DateTime orderDate;
  final DateTime deliveryDate;
  final int daysToDeliver;
  final String? delayReason;
}

final class DealershipDataset {
  DealershipDataset({
    required this.metadata,
    required List<Branch> branches,
    required List<SalesRep> salesReps,
    required List<Lead> leads,
    required List<Target> targets,
    required List<Delivery> deliveries,
  })  : branches = UnmodifiableListView(branches),
        salesReps = UnmodifiableListView(salesReps),
        leads = UnmodifiableListView(leads),
        targets = UnmodifiableListView(targets),
        deliveries = UnmodifiableListView(deliveries);

  final DealershipMetadata metadata;
  final List<Branch> branches;
  final List<SalesRep> salesReps;
  final List<Lead> leads;
  final List<Target> targets;
  final List<Delivery> deliveries;
}
