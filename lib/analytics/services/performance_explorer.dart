import '../../data/models/dealership_models.dart';
import '../models/analytical_lead.dart';
import '../models/analytics_results.dart';
import 'dealership_analytics_engine.dart';

enum ComparisonDimension { model, branch, representative, source }

enum ComparisonMetric {
  deliveries,
  deliveredValue,
  leads,
  conversion,
  activeCount,
  activeValue,
  staleCount,
  staleValue,
  overdueCount,
  lostCount,
  lostValue,
  averageValue,
  medianValue,
  contactRate,
  testDriveRate,
  closeRate,
  deliveryDays,
}

extension ComparisonMetricDefinition on ComparisonMetric {
  bool get isRate => const [
        ComparisonMetric.conversion,
        ComparisonMetric.contactRate,
        ComparisonMetric.testDriveRate,
        ComparisonMetric.closeRate
      ].contains(this);
  bool get usesDeliveries => const [
        ComparisonMetric.deliveries,
        ComparisonMetric.deliveredValue,
        ComparisonMetric.deliveryDays
      ].contains(this);
}

/// A row retains its contributing records. Counts of delivery events are not
/// deduplicated into customers, and cohort outcomes are not delivery-date sales.
class PerformanceSlice {
  const PerformanceSlice(
      {required this.id,
      required this.label,
      required this.leads,
      required this.deliveries,
      required this.overview,
      required this.pipeline,
      required this.gates,
      required this.deliveryStats,
      required this.deliveryValue,
      required this.lostValue,
      required this.mature});
  final String? id;
  final String label;
  final List<AnalyticalLead> leads;
  final List<Delivery> deliveries;
  final BusinessOverview overview;
  final PipelineOperationalAnalytics pipeline;
  final List<ManagementGateResult> gates;
  final DeliveryStats deliveryStats;
  final num deliveryValue;
  final num lostValue;
  final bool mature;

  num? value(ComparisonMetric metric) => switch (metric) {
        ComparisonMetric.deliveries => deliveries.length,
        ComparisonMetric.deliveredValue => deliveryValue,
        ComparisonMetric.leads => overview.totalLeads,
        ComparisonMetric.conversion => overview.resolvedConversion,
        ComparisonMetric.activeCount => overview.activeLeads,
        ComparisonMetric.activeValue => overview.activeOpportunityValue,
        ComparisonMetric.staleCount =>
          evidence(ComparisonMetric.staleCount).length,
        ComparisonMetric.staleValue => pipeline.staleValue,
        ComparisonMetric.overdueCount => pipeline.overdueExpectedClose.count,
        ComparisonMetric.lostCount => overview.lost,
        ComparisonMetric.lostValue => lostValue,
        ComparisonMetric.averageValue => overview.dealValue.average,
        ComparisonMetric.medianValue => overview.dealValue.median,
        ComparisonMetric.contactRate => gates[0].conversion,
        ComparisonMetric.testDriveRate => gates[1].conversion,
        ComparisonMetric.closeRate => gates[2].conversion,
        ComparisonMetric.deliveryDays => deliveryStats.medianDays,
      };

  List<String> evidence(ComparisonMetric metric) {
    if (metric.usesDeliveries) return deliveries.map((d) => d.leadId).toList();
    if (metric == ComparisonMetric.staleCount ||
        metric == ComparisonMetric.staleValue) {
      return pipeline.byInactivity.entries
          .where((e) =>
              e.key == PipelineAgeingBand.stale ||
              e.key == PipelineAgeingBand.severelyStale)
          .expand((e) => e.value.leadIds)
          .toList();
    }
    if (metric == ComparisonMetric.overdueCount) {
      return pipeline.overdueExpectedClose.leadIds;
    }
    return leads
        .where((lead) => switch (metric) {
              ComparisonMetric.conversion => lead.isResolved,
              ComparisonMetric.activeCount ||
              ComparisonMetric.activeValue =>
                lead.isActive,
              ComparisonMetric.lostCount ||
              ComparisonMetric.lostValue =>
                lead.isLost,
              ComparisonMetric.testDriveRate => lead.reachedContacted,
              ComparisonMetric.closeRate => lead.reachedTestDrive,
              _ => true,
            })
        .map((lead) => lead.id)
        .toList();
  }

  int? denominator(ComparisonMetric metric) => switch (metric) {
        ComparisonMetric.conversion => overview.resolvedLeads,
        ComparisonMetric.contactRate => gates[0].eligibleCount,
        ComparisonMetric.testDriveRate => gates[1].eligibleCount,
        ComparisonMetric.closeRate => gates[2].eligibleCount,
        _ => null,
      };
}

class MonthlyPerformance {
  const MonthlyPerformance(
      {required this.month, required this.slice, required this.partial});
  final DateTime month;
  final PerformanceSlice slice;
  final bool partial;
}

class PerformanceExploration {
  const PerformanceExploration(
      {required this.rows, required this.total, required this.months});
  final List<PerformanceSlice> rows;
  final PerformanceSlice total;
  final List<MonthlyPerformance> months;

  List<PerformanceSlice> ranked(ComparisonMetric metric,
      {bool ascending = false}) {
    final result = [...rows];
    result.sort((a, b) {
      final av = a.value(metric), bv = b.value(metric);
      if (av == null || bv == null) {
        return av == bv
            ? a.label.compareTo(b.label)
            : av == null
                ? 1
                : -1;
      }
      final comparison = ascending ? av.compareTo(bv) : bv.compareTo(av);
      return comparison == 0 ? a.label.compareTo(b.label) : comparison;
    });
    return result;
  }

  /// Changes are unavailable across partial extracts or immature cohorts.
  /// Rates return percentage points; other measures return absolute units.
  num? monthChange(int index, ComparisonMetric metric) {
    if (index < 1 || index >= months.length) return null;
    final a = months[index - 1], b = months[index];
    if (a.partial ||
        b.partial ||
        (metric == ComparisonMetric.conversion &&
            (!a.slice.mature || !b.slice.mature))) return null;
    final previous = a.slice.value(metric), current = b.slice.value(metric);
    return previous == null || current == null
        ? null
        : (current - previous) * (metric.isRate ? 100 : 1);
  }
}

/// Reuses the canonical engine for cohort, gate, pipeline and delivery metrics.
/// [dimensionScope] has dimension filters but no date filter; the other scopes
/// have the current creation-date / delivery-date filters applied separately.
class PerformanceExplorer {
  const PerformanceExplorer();

  PerformanceExploration calculate(
      {required AnalyticalDataset dimensionScope,
      required AnalyticalDataset leadScope,
      required AnalyticalDataset deliveryScope,
      required DealershipDataset fullSource,
      required ComparisonDimension dimension,
      DateTime? start,
      DateTime? end}) {
    String? key(AnalyticalLead l) => switch (dimension) {
          ComparisonDimension.model => l.vehicleModel,
          ComparisonDimension.branch => l.branchId,
          ComparisonDimension.representative => l.repId,
          ComparisonDimension.source => l.source,
        };
    final names = <String?, String>{
      for (final lead in dimensionScope.leads)
        key(lead): key(lead) ?? 'Unattributed',
    };
    if (dimension == ComparisonDimension.branch) {
      for (final branch in dimensionScope.source.branches) {
        names[branch.id] = branch.name;
      }
    }
    if (dimension == ComparisonDimension.representative) {
      for (final rep in dimensionScope.source.salesReps) {
        if (rep.role.value == SalesRepRole.salesOfficer ||
            names.containsKey(rep.id)) {
          names[rep.id] = rep.name;
        }
      }
    }
    final deliveryLeads = {for (final l in deliveryScope.leads) l.id: l};
    final records = deliveryScope.source.deliveries
        .where((d) => deliveryLeads.containsKey(d.leadId))
        .toList();
    PerformanceSlice make(String? id, String label, List<AnalyticalLead> leads,
            List<Delivery> deliveries) =>
        _slice(id, label, leads, deliveries, dimensionScope);
    final rows = names.entries
        .map((entry) => make(
            entry.key,
            entry.value,
            leadScope.leads.where((l) => key(l) == entry.key).toList(),
            records
                .where((d) => key(deliveryLeads[d.leadId]!) == entry.key)
                .toList()))
        .toList();
    final total = make(null, 'Current view', leadScope.leads, records);
    final dates = [
      ...fullSource.leads.map((l) => _date(l.createdAt)),
      ...fullSource.deliveries.map((d) => _date(d.deliveryDate))
    ]..sort();
    final months = <MonthlyPerformance>[];
    if (dates.isNotEmpty) {
      final first = dates.first;
      final snapshot = _date(dimensionScope.context.snapshotDate);
      final from = start != null && start.isAfter(first) ? start : first;
      final to = end != null && end.isBefore(snapshot) ? end : snapshot;
      // Bound traversal to observed coverage, including months with zero records.
      for (var m = DateTime.utc(from.year, from.month);
          !m.isAfter(to);
          m = DateTime.utc(m.year, m.month + 1)) {
        final last = DateTime.utc(m.year, m.month + 1, 0);
        bool inMonth(DateTime date) =>
            date.year == m.year && date.month == m.month;
        months.add(MonthlyPerformance(
            month: m,
            partial: from.isAfter(m) || to.isBefore(last),
            slice: make(
                null,
                '${m.year}-${m.month}',
                leadScope.leads
                    .where((l) => inMonth(l.lead.createdAt))
                    .toList(),
                records.where((d) => inMonth(d.deliveryDate)).toList())));
      }
    }
    return PerformanceExploration(rows: rows, total: total, months: months);
  }

  PerformanceSlice _slice(String? id, String label, List<AnalyticalLead> leads,
      List<Delivery> deliveries, AnalyticalDataset context) {
    final engine = DealershipAnalyticsEngine(context);
    final lookup = {for (final l in context.leads) l.id: l};
    final deliveryEngine = DealershipAnalyticsEngine(AnalyticalDataset(
        source: DealershipDataset(
            metadata: context.source.metadata,
            branches: context.source.branches,
            salesReps: context.source.salesReps,
            leads: deliveries.map((d) => lookup[d.leadId]!.lead).toList(),
            targets: const [],
            deliveries: deliveries),
        context: context.context,
        leads: deliveries.map((d) => lookup[d.leadId]!).toSet().toList()));
    final cohorts = engine.cohorts(leads);
    return PerformanceSlice(
        id: id,
        label: label,
        leads: leads,
        deliveries: deliveries,
        overview: engine.businessOverview(leads),
        pipeline: engine.pipelineOperations(leads),
        gates: engine.managementGates(leads),
        deliveryStats: deliveryEngine.deliveries().overall,
        deliveryValue: deliveries.fold<num>(
            0, (sum, d) => sum + lookup[d.leadId]!.dealValue),
        lostValue: engine
            .lostReasons(leads)
            .fold<num>(0, (sum, r) => sum + r.total.affectedValue),
        mature: cohorts.isNotEmpty && cohorts.every((c) => c.isMature));
  }

  static DateTime _date(DateTime d) => DateTime.utc(d.year, d.month, d.day);
}
