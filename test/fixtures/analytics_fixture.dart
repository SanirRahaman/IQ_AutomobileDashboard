import 'package:yoyota_dealers/data/models/dealership_models.dart';

DateTime day(int day, [int hour = 0]) => DateTime.utc(2025, 1, day, hour);

LeadStatusHistoryEntry history(
  LeadStatus status,
  DateTime timestamp, {
  String? note,
}) =>
    LeadStatusHistoryEntry(
      status: LeadStatusValue.fromRaw(_statusRaw(status)),
      timestamp: timestamp,
      note: note,
    );

Lead lead({
  required String id,
  required LeadStatus status,
  required List<LeadStatusHistoryEntry> journey,
  String branchId = 'B1',
  String repId = 'R1',
  String? source = 'web',
  String model = 'Model A',
  num value = 100,
  DateTime? createdAt,
  DateTime? lastActivityAt,
  DateTime? expectedCloseDate,
  String? lostReason,
}) =>
    Lead(
      id: id,
      customerName: 'Customer $id',
      phone: id,
      source: source,
      modelInterested: model,
      status: LeadStatusValue.fromRaw(_statusRaw(status)),
      assignedTo: repId,
      branchId: branchId,
      createdAt: createdAt ?? day(1),
      lastActivityAt: lastActivityAt ?? journey.last.timestamp,
      statusHistory: journey,
      expectedCloseDate: expectedCloseDate ?? day(20),
      dealValue: value,
      lostReason: lostReason,
    );

DealershipDataset dataset({
  required List<Lead> leads,
  List<Delivery> deliveries = const [],
}) =>
    DealershipDataset(
      metadata: DealershipMetadata(
        generatedAt: day(31),
        description: 'Analytics fixture',
        dateRange: 'January 2025',
        notes: 'Synthetic',
      ),
      branches: const [
        Branch(id: 'B1', name: 'Branch One', city: 'City'),
        Branch(id: 'B2', name: 'Branch Two', city: 'City'),
      ],
      salesReps: [
        SalesRep(
          id: 'R1',
          name: 'Rep One',
          branchId: 'B1',
          role: SalesRepRoleValue.fromRaw('sales_officer'),
          joined: DateTime.utc(2024, 1, 1),
        ),
        SalesRep(
          id: 'R2',
          name: 'Rep Two',
          branchId: 'B2',
          role: SalesRepRoleValue.fromRaw('sales_officer'),
          joined: DateTime.utc(2024, 6, 1),
        ),
        SalesRep(
          id: 'M1',
          name: 'Manager',
          branchId: 'B1',
          role: SalesRepRoleValue.fromRaw('branch_manager'),
          joined: DateTime.utc(2023, 1, 1),
        ),
      ],
      leads: leads,
      targets: const [],
      deliveries: deliveries,
    );

List<LeadStatusHistoryEntry> deliveredJourney({int offset = 0}) => [
      history(LeadStatus.newLead, day(1 + offset)),
      history(LeadStatus.contacted, day(2 + offset)),
      history(LeadStatus.testDrive, day(3 + offset)),
      history(LeadStatus.negotiation, day(4 + offset)),
      history(LeadStatus.orderPlaced, day(5 + offset)),
      history(LeadStatus.delivered, day(7 + offset)),
    ];

String _statusRaw(LeadStatus status) => switch (status) {
      LeadStatus.newLead => 'new',
      LeadStatus.contacted => 'contacted',
      LeadStatus.testDrive => 'test_drive',
      LeadStatus.negotiation => 'negotiation',
      LeadStatus.orderPlaced => 'order_placed',
      LeadStatus.delivered => 'delivered',
      LeadStatus.lost => 'lost',
      LeadStatus.unknown => 'unknown_fixture',
    };
