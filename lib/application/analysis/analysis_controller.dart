import 'package:flutter/foundation.dart';

import '../../analytics/models/analytical_lead.dart';
import '../../analytics/services/dealership_analytics_engine.dart';
import '../../analytics/services/lead_feature_engineer.dart';
import '../../data/models/dealership_models.dart';
import '../../data/repositories/dealership_dataset_repository.dart';
import '../../data/validation/validation.dart';
import '../../insights/services/deterministic_insight_engine.dart';
import 'analysis_filters.dart';
import '../../analytics/services/management_performance.dart';
import '../../analytics/services/performance_explorer.dart';
import 'analysis_results.dart';
import 'analysis_route_codec.dart';
import 'analysis_scope_service.dart';

final class AnalysisController extends ChangeNotifier {
  AnalysisController({
    required DealershipDataset dataset,
    ValidationReport? validationReport,
    AnalysisFilters initialFilters = const AnalysisFilters(),
    LeadFeatureEngineer featureEngineer = const LeadFeatureEngineer(),
    AnalysisScopeService scopeService = const AnalysisScopeService(),
    DeterministicInsightEngine insightEngine =
        const DeterministicInsightEngine(),
    AnalysisRouteCodec routeCodec = const AnalysisRouteCodec(),
  })  : _dataset = dataset,
        _validationReport = validationReport ?? ValidationReport(),
        _scopeService = scopeService,
        _insightEngine = insightEngine,
        _routeCodec = routeCodec,
        _fullAnalyticalDataset = featureEngineer.build(dataset),
        _filters = const AnalysisFilters(),
        _results = null {
    _filters = _normalize(initialFilters);
    _results = _calculate(_filters);
  }

  static Future<AnalysisController> load(
    DealershipRepository repository, {
    AnalysisFilters initialFilters = const AnalysisFilters(),
  }) async {
    final loaded = await repository.load();
    if (!loaded.isCompatible || loaded.dataset == null) {
      final messages = loaded.report.fatalParsingErrors
          .map((issue) => '${issue.path}: ${issue.message}')
          .join('; ');
      throw StateError('Unable to initialize analysis state: $messages');
    }
    return AnalysisController(
      dataset: loaded.dataset!,
      validationReport: loaded.report,
      initialFilters: initialFilters,
    );
  }

  final DealershipDataset _dataset;
  final ValidationReport _validationReport;
  final AnalysisScopeService _scopeService;
  final DeterministicInsightEngine _insightEngine;
  final AnalysisRouteCodec _routeCodec;
  final AnalyticalDataset _fullAnalyticalDataset;
  AnalysisFilters _filters;
  AnalysisResults? _results;

  AnalysisFilters get filters => _filters;
  AnalysisResults get results => _results!;
  DealershipDataset get dataset => _dataset;
  ValidationReport get validationReport => _validationReport;

  PerformanceExploration explore(ComparisonDimension dimension) =>
      const PerformanceExplorer().calculate(
        dimensionScope: _scopeService
            .apply(_fullAnalyticalDataset, _filters.copyWith(dateRange: null))
            .leadScope,
        leadScope: results.leadScope,
        deliveryScope: results.deliveryScope,
        fullSource: _dataset,
        dimension: dimension,
        start: _filters.dateRange?.start,
        end: _filters.dateRange?.end,
      );

  List<SalesRep> get availableSalesReps => _dataset.salesReps
      .where((rep) =>
          _filters.branchId == null || rep.branchId == _filters.branchId)
      .toList(growable: false);

  Uri get routeUri => _routeCodec.encode(_filters);

  void setDateRange(AnalysisDateRange? value) =>
      _setFilters(_filters.copyWith(dateRange: value));

  void setBranch(String? branchId) => _setFilters(_filters.copyWith(
        branchId: branchId,
        repId: _repBelongsToBranch(_filters.repId, branchId)
            ? _filters.repId
            : null,
      ));

  void setSalesRep(String? repId) {
    final rep =
        _dataset.salesReps.where((item) => item.id == repId).firstOrNull;
    _setFilters(_filters.copyWith(
      repId: rep?.id,
      branchId: rep == null ? _filters.branchId : rep.branchId,
    ));
  }

  void setSource(String? source) =>
      _setFilters(_filters.copyWith(source: source));

  void setVehicleModel(String? model) =>
      _setFilters(_filters.copyWith(vehicleModel: model));

  void setLeadStatus(String? rawStatus) =>
      _setFilters(_filters.copyWith(leadStatus: rawStatus));

  void replaceFilters(AnalysisFilters filters) =>
      _setFilters(_normalize(filters));

  void applyRoute(Uri uri) => replaceFilters(_routeCodec.decode(uri, _dataset));

  void reset() => _setFilters(const AnalysisFilters());

  void _setFilters(AnalysisFilters value) {
    final normalized = _normalize(value);
    if (normalized == _filters) return;
    _filters = normalized;
    _results = _calculate(normalized);
    notifyListeners();
  }

  AnalysisFilters _normalize(AnalysisFilters value) {
    final branchExists = value.branchId == null ||
        _dataset.branches.any((branch) => branch.id == value.branchId);
    final branchId = branchExists ? value.branchId : null;
    final rep =
        _dataset.salesReps.where((item) => item.id == value.repId).firstOrNull;
    final repId = rep != null && (branchId == null || rep.branchId == branchId)
        ? rep.id
        : null;
    return value.copyWith(
        branchId: repId == null ? branchId : rep!.branchId, repId: repId);
  }

  bool _repBelongsToBranch(String? repId, String? branchId) {
    if (repId == null || branchId == null) return repId == null;
    return _dataset.salesReps
        .any((rep) => rep.id == repId && rep.branchId == branchId);
  }

  AnalysisResults _calculate(AnalysisFilters filters) {
    final scopes = _scopeService.apply(_fullAnalyticalDataset, filters);
    final analytics = DealershipAnalyticsEngine(scopes.leadScope);
    final deliveryAnalytics = DealershipAnalyticsEngine(scopes.deliveryScope);
    final scopedValidation =
        _scopeValidation(scopes.leadScope.leads.map((lead) => lead.id).toSet());
    return AnalysisResults(
      filters: filters,
      performance: const ManagementPerformanceService().calculate(
          _fullAnalyticalDataset,
          start: filters.dateRange?.start,
          end: filters.dateRange?.end,
          branchId: filters.branchId,
          repId: filters.repId,
          source: filters.source,
          model: filters.vehicleModel,
          status: filters.leadStatus),
      leadScope: scopes.leadScope,
      deliveryScope: scopes.deliveryScope,
      overview: analytics.businessOverview(),
      funnel: analytics.funnel(),
      managementGates: analytics.managementGates(),
      branches: analytics.branches(),
      salesReps: analytics.salesReps(),
      sources: analytics.sources(),
      vehicles: analytics.vehicles(),
      lostReasons: analytics.lostReasons(),
      pipeline: analytics.pipeline(),
      pipelineOperations: analytics.pipelineOperations(),
      deliveries: deliveryAnalytics.deliveries(),
      cohorts: analytics.cohorts(),
      insights: _insightEngine.generate(
        scopes.leadScope,
        deliveryDataset: scopes.deliveryScope,
        validationReport: scopedValidation,
      ),
    );
  }

  ValidationReport _scopeValidation(Set<String> leadIds) => ValidationReport(
        _validationReport.issues.where((issue) =>
            issue.recordId == null || leadIds.contains(issue.recordId)),
      );
}
