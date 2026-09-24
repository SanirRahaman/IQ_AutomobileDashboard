import '../../analytics/models/analytical_lead.dart';
import '../../data/models/dealership_models.dart';

enum EvidenceOrder {
  original,
  highestValue,
  lowestValue,
  inactivity,
  overdue,
  oldest,
  longestDelivery,
  shortestDelivery
}

/// Sort positions rather than IDs: two deliveries for one lead stay distinct.
List<int> orderedEvidence(
    {required List<String> ids,
    required Map<String, AnalyticalLead> records,
    required EvidenceOrder order,
    List<Delivery>? deliveries}) {
  final positions = List<int>.generate(ids.length, (i) => i);
  num? value(int i) {
    final record = records[ids[i]];
    if (record == null) return null;
    return switch (order) {
      EvidenceOrder.original => i,
      EvidenceOrder.highestValue ||
      EvidenceOrder.lowestValue =>
        record.dealValue,
      EvidenceOrder.inactivity =>
        record.isActive ? record.daysSinceLastActivity : null,
      EvidenceOrder.overdue =>
        record.isActive ? record.expectedCloseSlippage?.inDays : null,
      EvidenceOrder.oldest =>
        record.context.snapshotDate.difference(record.lead.createdAt).inDays,
      EvidenceOrder.longestDelivery ||
      EvidenceOrder.shortestDelivery =>
        deliveries?[i].daysToDeliver,
    };
  }

  final ascending = order == EvidenceOrder.original ||
      order == EvidenceOrder.lowestValue ||
      order == EvidenceOrder.shortestDelivery;
  positions.sort((a, b) {
    final av = value(a), bv = value(b);
    if (av == null || bv == null) {
      return av == bv
          ? a.compareTo(b)
          : av == null
              ? 1
              : -1;
    }
    final result = ascending ? av.compareTo(bv) : bv.compareTo(av);
    return result == 0 ? a.compareTo(b) : result;
  });
  return positions;
}
