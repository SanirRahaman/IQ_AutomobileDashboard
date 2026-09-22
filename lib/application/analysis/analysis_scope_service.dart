import '../../analytics/models/analytical_lead.dart';
import '../../data/models/dealership_models.dart';
import 'analysis_filters.dart';

final class ScopedAnalysisDatasets {
  const ScopedAnalysisDatasets({
    required this.leadScope,
    required this.deliveryScope,
  });

  /// Creation-date scoped dataset used by lead, cohort, and funnel analytics.
  final AnalyticalDataset leadScope;

  /// Delivery-date scoped dataset used only by delivery analytics and rules.
  final AnalyticalDataset deliveryScope;
}

final class AnalysisScopeService {
  const AnalysisScopeService();

  ScopedAnalysisDatasets apply(
    AnalyticalDataset fullDataset,
    AnalysisFilters filters,
  ) {
    final dimensionRecords = fullDataset.leads
        .where((record) => filters.matchesDimensions(record.lead))
        .toList(growable: false);
    final leadRecords = dimensionRecords
        .where((record) => filters.matchesLeadDate(record.lead))
        .toList(growable: false);

    final dimensionLeadIds = dimensionRecords.map((lead) => lead.id).toSet();
    final deliveries = fullDataset.source.deliveries
        .where((delivery) =>
            dimensionLeadIds.contains(delivery.leadId) &&
            filters.matchesDeliveryDate(delivery))
        .toList(growable: false);
    final deliveryLeadIds =
        deliveries.map((delivery) => delivery.leadId).toSet();
    final deliveryRecords = dimensionRecords
        .where((record) => deliveryLeadIds.contains(record.id))
        .toList(growable: false);

    return ScopedAnalysisDatasets(
      leadScope: AnalyticalDataset(
        source: _scopedSource(
          fullDataset.source,
          filters,
          leadRecords.map((record) => record.lead).toList(),
          const <Delivery>[],
        ),
        context: fullDataset.context,
        leads: leadRecords,
      ),
      deliveryScope: AnalyticalDataset(
        source: _scopedSource(
          fullDataset.source,
          filters,
          deliveryRecords.map((record) => record.lead).toList(),
          deliveries,
        ),
        context: fullDataset.context,
        leads: deliveryRecords,
      ),
    );
  }

  DealershipDataset _scopedSource(
    DealershipDataset source,
    AnalysisFilters filters,
    List<Lead> leads,
    List<Delivery> deliveries,
  ) {
    final branchIds = filters.branchId == null
        ? source.branches.map((branch) => branch.id).toSet()
        : {filters.branchId!};
    final branches = source.branches
        .where((branch) => branchIds.contains(branch.id))
        .toList(growable: false);
    final reps = source.salesReps.where((rep) {
      if (filters.repId != null) return rep.id == filters.repId;
      return filters.branchId == null || rep.branchId == filters.branchId;
    }).toList(growable: false);
    final targetBranches = branches.map((branch) => branch.id).toSet();
    return DealershipDataset(
      metadata: source.metadata,
      branches: branches,
      salesReps: reps,
      leads: leads,
      targets: source.targets
          .where((target) => targetBranches.contains(target.branchId))
          .toList(growable: false),
      deliveries: deliveries,
    );
  }
}
