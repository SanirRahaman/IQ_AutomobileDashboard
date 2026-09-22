import '../../data/models/dealership_models.dart';

/// Inclusive UTC calendar-date range used by analytical scoping.
final class AnalysisDateRange {
  AnalysisDateRange({required DateTime start, required DateTime end})
      : start = _utcDate(start),
        end = _utcDate(end) {
    if (this.end.isBefore(this.start)) {
      throw ArgumentError.value(end, 'end', 'Must be on or after start.');
    }
  }

  final DateTime start;
  final DateTime end;

  bool includes(DateTime timestamp) {
    final date = _utcDate(timestamp.toUtc());
    return !date.isBefore(start) && !date.isAfter(end);
  }

  static DateTime _utcDate(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  @override
  bool operator ==(Object other) =>
      other is AnalysisDateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

final class AnalysisFilters {
  const AnalysisFilters({
    this.dateRange,
    this.branchId,
    this.repId,
    this.source,
    this.vehicleModel,
    this.leadStatus,
  });

  final AnalysisDateRange? dateRange;
  final String? branchId;
  final String? repId;
  final String? source;
  final String? vehicleModel;

  /// Raw canonical status value, preserving support for future unknown values.
  final String? leadStatus;

  bool get isDefault =>
      dateRange == null &&
      branchId == null &&
      repId == null &&
      source == null &&
      vehicleModel == null &&
      leadStatus == null;

  bool matchesDimensions(Lead lead) =>
      (branchId == null || lead.branchId == branchId) &&
      (repId == null || lead.assignedTo == repId) &&
      (source == null || lead.source == source) &&
      (vehicleModel == null || lead.modelInterested == vehicleModel) &&
      (leadStatus == null || lead.status.rawValue == leadStatus);

  bool matchesLeadDate(Lead lead) =>
      dateRange == null || dateRange!.includes(lead.createdAt);

  bool matchesDeliveryDate(Delivery delivery) =>
      dateRange == null || dateRange!.includes(delivery.deliveryDate);

  AnalysisFilters copyWith({
    Object? dateRange = _unchanged,
    Object? branchId = _unchanged,
    Object? repId = _unchanged,
    Object? source = _unchanged,
    Object? vehicleModel = _unchanged,
    Object? leadStatus = _unchanged,
  }) =>
      AnalysisFilters(
        dateRange: identical(dateRange, _unchanged)
            ? this.dateRange
            : dateRange as AnalysisDateRange?,
        branchId: identical(branchId, _unchanged)
            ? this.branchId
            : branchId as String?,
        repId: identical(repId, _unchanged) ? this.repId : repId as String?,
        source: identical(source, _unchanged) ? this.source : source as String?,
        vehicleModel: identical(vehicleModel, _unchanged)
            ? this.vehicleModel
            : vehicleModel as String?,
        leadStatus: identical(leadStatus, _unchanged)
            ? this.leadStatus
            : leadStatus as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is AnalysisFilters &&
      other.dateRange == dateRange &&
      other.branchId == branchId &&
      other.repId == repId &&
      other.source == source &&
      other.vehicleModel == vehicleModel &&
      other.leadStatus == leadStatus;

  @override
  int get hashCode => Object.hash(
        dateRange,
        branchId,
        repId,
        source,
        vehicleModel,
        leadStatus,
      );
}

const _unchanged = Object();
