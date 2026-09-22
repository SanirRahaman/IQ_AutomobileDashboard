import 'dart:collection';

import '../../data/models/dealership_models.dart';

final class DealershipDatasetIndexes {
  DealershipDatasetIndexes._({
    required this.branchById,
    required this.repById,
    required this.leadById,
    required this.repsByBranch,
    required this.leadsByBranch,
    required this.leadsByRep,
  });

  final Map<String, Branch> branchById;
  final Map<String, SalesRep> repById;
  final Map<String, Lead> leadById;
  final Map<String, List<SalesRep>> repsByBranch;
  final Map<String, List<Lead>> leadsByBranch;
  final Map<String, List<Lead>> leadsByRep;

  factory DealershipDatasetIndexes.build(DealershipDataset dataset) {
    final repsByBranch = <String, List<SalesRep>>{};
    for (final rep in dataset.salesReps) {
      repsByBranch.putIfAbsent(rep.branchId, () => []).add(rep);
    }
    final leadsByBranch = <String, List<Lead>>{};
    final leadsByRep = <String, List<Lead>>{};
    for (final lead in dataset.leads) {
      leadsByBranch.putIfAbsent(lead.branchId, () => []).add(lead);
      leadsByRep.putIfAbsent(lead.assignedTo, () => []).add(lead);
    }

    return DealershipDatasetIndexes._(
      branchById: _byId(dataset.branches, (item) => item.id),
      repById: _byId(dataset.salesReps, (item) => item.id),
      leadById: _byId(dataset.leads, (item) => item.id),
      repsByBranch: _freezeGroups(repsByBranch),
      leadsByBranch: _freezeGroups(leadsByBranch),
      leadsByRep: _freezeGroups(leadsByRep),
    );
  }

  static Map<String, T> _byId<T>(
    Iterable<T> values,
    String Function(T value) id,
  ) =>
      UnmodifiableMapView({for (final value in values) id(value): value});

  static Map<String, List<T>> _freezeGroups<T>(Map<String, List<T>> values) =>
      UnmodifiableMapView({
        for (final entry in values.entries)
          entry.key: UnmodifiableListView(entry.value),
      });
}
