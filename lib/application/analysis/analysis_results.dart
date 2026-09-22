import '../../analytics/models/analytical_lead.dart';
import '../../analytics/models/analytics_results.dart';
import '../../insights/models/management_insight.dart';
import 'analysis_filters.dart';
import '../../analytics/services/management_performance.dart';

final class AnalysisResults {
  const AnalysisResults({
    required this.filters,
    required this.performance,
    required this.leadScope,
    required this.deliveryScope,
    required this.overview,
    required this.funnel,
    required this.managementGates,
    required this.branches,
    required this.salesReps,
    required this.sources,
    required this.vehicles,
    required this.lostReasons,
    required this.pipeline,
    required this.pipelineOperations,
    required this.deliveries,
    required this.cohorts,
    required this.insights,
  });

  final AnalysisFilters filters;
  final ManagementPerformance performance;
  final AnalyticalDataset leadScope;
  final AnalyticalDataset deliveryScope;
  final BusinessOverview overview;
  final List<FunnelStageResult> funnel;
  final List<ManagementGateResult> managementGates;
  final List<BranchAnalytics> branches;
  final List<SalesRepAnalytics> salesReps;
  final List<SourceAnalytics> sources;
  final List<VehicleAnalytics> vehicles;
  final List<LostReasonAnalytics> lostReasons;
  final List<PipelineOpportunity> pipeline;
  final PipelineOperationalAnalytics pipelineOperations;
  final DeliveryAnalytics deliveries;
  final List<CohortAnalytics> cohorts;
  final List<ManagementInsight> insights;
}
