import '../../data/models/dealership_models.dart';
import '../models/analytical_lead.dart';

/// Delivery-date actuals matched only to explicitly supplied branch-month targets.
/// Partial months keep their full target; targets are never prorated or allocated
/// to representatives, lead sources, models, or statuses.
class TargetPerformance {
  const TargetPerformance(
      {required this.branchId,
      required this.branchName,
      required this.actual,
      required this.target,
      required this.missingMonths,
      required this.partialPeriod,
      required this.leadIds});
  final String? branchId;
  final String branchName;
  final int actual;
  final int? target;
  final int missingMonths;
  final bool partialPeriod;
  final List<String> leadIds;
  int? get variance => target == null ? null : actual - target!;
  double? get attainment =>
      target == null || target == 0 ? null : actual / target!;
  double get progress => (attainment ?? 0).clamp(0.0, 1.0);
  String get status => target == null
      ? 'No comparable target'
      : target == 0
          ? 'Zero target · percentage unavailable'
          : partialPeriod
              ? 'Partial period · full monthly target'
              : variance! < 0
                  ? '${-variance!} below target'
                  : variance! > 0
                      ? '${variance!} above target'
                      : 'Target met';
}

class DeliveryComparison {
  const DeliveryComparison(
      {required this.current,
      required this.previous,
      required this.previousStart,
      required this.previousEnd});
  final int current;
  final int previous;
  final DateTime previousStart;
  final DateTime previousEnd;
  int get difference => current - previous;
}

class ManagementPerformance {
  const ManagementPerformance(
      {required this.start,
      required this.end,
      required this.snapshot,
      required this.branches,
      required this.total,
      required this.unavailableReason,
      required this.comparison,
      required this.deliveredCount,
      required this.deliveredValue});
  final DateTime start;
  final DateTime end;
  final DateTime snapshot;
  final List<TargetPerformance> branches;
  final TargetPerformance? total;
  final String? unavailableReason;
  final DeliveryComparison? comparison;
  final int deliveredCount;
  final num deliveredValue;
}

class ManagementPerformanceService {
  const ManagementPerformanceService();

  ManagementPerformance calculate(
    AnalyticalDataset data, {
    DateTime? start,
    DateTime? end,
    String? branchId,
    String? repId,
    String? source,
    String? model,
    String? status,
  }) {
    final snapshot = _date(data.context.snapshotDate);
    final observed = [
      ...data.source.leads.map((l) => _date(l.createdAt)),
      ...data.source.deliveries.map((d) => _date(d.deliveryDate)),
    ]..sort();
    final first = observed.isEmpty ? snapshot : observed.first;
    final from = start ?? DateTime.utc(first.year, first.month);
    final to = end ?? snapshot;
    final leads = {for (final l in data.source.leads) l.id: l};
    bool matches(Lead l) =>
        (branchId == null || l.branchId == branchId) &&
        (repId == null || l.assignedTo == repId) &&
        (source == null || l.source == source) &&
        (model == null || l.modelInterested == model) &&
        (status == null || l.status.rawValue == status);
    List<Delivery> delivered(DateTime a, DateTime b) =>
        data.source.deliveries.where((d) {
          final l = leads[d.leadId];
          final date = _date(d.deliveryDate);
          return l != null &&
              matches(l) &&
              !date.isBefore(a) &&
              !date.isAfter(b);
        }).toList();
    final current = delivered(from, to);
    final selectedBranches =
        data.source.branches.where((b) => branchId == null || b.id == branchId);
    final months = <DateTime>[];
    // Bound traversal by supplied targets, not arbitrary URL date ranges.
    final targetMonths = data.source.targets
        .map((t) => DateTime.utc(t.month.year, t.month.month))
        .toSet()
        .toList()
      ..sort();
    // Also count months with no target anywhere in the observed coverage.
    for (var month = DateTime.utc(first.year, first.month);
        !month.isAfter(snapshot);
        month = DateTime.utc(month.year, month.month + 1)) {
      if (!targetMonths.contains(month)) targetMonths.add(month);
    }
    targetMonths.sort();
    for (final m in targetMonths) {
      final last = DateTime.utc(m.year, m.month + 1, 0);
      if (!last.isBefore(from) && !m.isAfter(to)) months.add(m);
    }
    final dimensionFiltered =
        repId != null || source != null || model != null || status != null;
    final rows = <TargetPerformance>[];
    if (!dimensionFiltered) {
      for (final b in selectedBranches) {
        var target = 0;
        var supported = 0;
        var missing = 0;
        var partial = false;
        final ids = <String>[];
        for (final m in months) {
          final ts = data.source.targets
              .where((t) =>
                  t.branchId == b.id &&
                  t.month.year == m.year &&
                  t.month.month == m.month)
              .toList();
          // Duplicate/invalid targets cannot be unambiguously combined.
          if (ts.length != 1 || ts.single.targetUnits < 0) {
            missing++;
            continue;
          }
          supported++;
          target += ts.single.targetUnits;
          final last = DateTime.utc(m.year, m.month + 1, 0);
          partial |=
              from.isAfter(m) || to.isBefore(last) || snapshot.isBefore(last);
          ids.addAll(current
              .where((d) =>
                  leads[d.leadId]!.branchId == b.id &&
                  d.deliveryDate.year == m.year &&
                  d.deliveryDate.month == m.month)
              .map((d) => d.leadId));
        }
        rows.add(TargetPerformance(
            branchId: b.id,
            branchName: b.name,
            actual: ids.length,
            target: supported == 0 ? null : target,
            missingMonths: missing,
            partialPeriod: partial,
            leadIds: ids));
      }
    }
    final supported = rows.where((r) => r.target != null).toList();
    final total = supported.isEmpty
        ? null
        : TargetPerformance(
            branchId: null,
            branchName: 'Selected branches',
            actual: supported.fold(0, (s, r) => s + r.actual),
            target: supported.fold<int>(0, (s, r) => s + r.target!),
            missingMonths: rows.fold(0, (s, r) => s + r.missingMonths),
            partialPeriod: rows.any((r) => r.partialPeriod),
            leadIds: supported.expand((r) => r.leadIds).toList());
    // Compare delivery events only for two fully observed calendar months.
    // Creation-cohort conversion is deliberately not compared here.
    DeliveryComparison? comparison;
    final monthEnd = DateTime.utc(from.year, from.month + 1, 0);
    final priorStart = DateTime.utc(from.year, from.month - 1);
    final priorEnd = DateTime.utc(from.year, from.month, 0);
    if (start != null &&
        from.day == 1 &&
        to == monthEnd &&
        !to.isAfter(snapshot) &&
        !priorStart.isBefore(first)) {
      comparison = DeliveryComparison(
          current: current.length,
          previous: delivered(priorStart, priorEnd).length,
          previousStart: priorStart,
          previousEnd: priorEnd);
    }
    return ManagementPerformance(
        start: from,
        end: to,
        snapshot: snapshot,
        branches: rows,
        total: total,
        unavailableReason: dimensionFiltered
            ? 'Targets are supplied by branch and month only. Clear representative, source, model and status filters to compare targets.'
            : total == null
                ? 'No comparable branch targets are available for this period.'
                : null,
        comparison: comparison,
        deliveredCount: current.length,
        deliveredValue:
            current.fold<num>(0, (s, d) => s + leads[d.leadId]!.dealValue));
  }

  static DateTime _date(DateTime d) => DateTime.utc(d.year, d.month, d.day);
}
