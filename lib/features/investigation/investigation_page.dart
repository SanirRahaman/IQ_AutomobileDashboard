import '../dashboard/dashboard_view_data.dart';
import '../shared/target_panel.dart';
import '../../app/analysis_router.dart';
import 'package:flutter/material.dart';

import '../../application/analysis/analysis_controller.dart';
import '../../application/analysis/analysis_filters.dart';
import '../../app/app_theme.dart';
import '../../insights/models/management_insight.dart';
import 'investigation_view_data.dart';
import 'lead_evidence_dialog.dart';

class BranchDetailPage extends StatefulWidget {
  const BranchDetailPage({
    super.key,
    required this.baseController,
    required this.branchId,
  });

  final AnalysisController baseController;
  final String branchId;

  @override
  State<BranchDetailPage> createState() => _BranchDetailPageState();
}

class _BranchDetailPageState extends State<BranchDetailPage> {
  static const _presenter = InvestigationPresenter();
  late final AnalysisController _network;
  late final AnalysisController _scoped;
  late final InvestigationViewData? _viewData;

  @override
  void initState() {
    super.initState();
    final exists = widget.baseController.dataset.branches
        .any((item) => item.id == widget.branchId);
    if (!exists) {
      _network = _controller(widget.baseController.filters.copyWith(
        branchId: null,
        repId: null,
      ));
      _scoped = _controller(widget.baseController.filters);
      _viewData = null;
      return;
    }
    _network = _controller(widget.baseController.filters.copyWith(
      branchId: null,
      repId: null,
    ));
    _scoped = _controller(widget.baseController.filters.copyWith(
      branchId: widget.branchId,
      repId: null,
    ));
    _viewData = _presenter.branch(scoped: _scoped, network: _network);
  }

  AnalysisController _controller(AnalysisFilters filters) => AnalysisController(
        dataset: widget.baseController.dataset,
        validationReport: widget.baseController.validationReport,
        initialFilters: filters,
      );

  @override
  void dispose() {
    _network.dispose();
    _scoped.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _viewData == null
      ? _NotFound(kind: 'branch', id: widget.branchId)
      : _InvestigationScaffold(
          viewData: _viewData,
          scopedController: _scoped,
          benchmarkLabel: 'Network benchmark',
          repNavigation: true,
        );
}

class RepDetailPage extends StatefulWidget {
  const RepDetailPage({
    super.key,
    required this.baseController,
    required this.repId,
  });

  final AnalysisController baseController;
  final String repId;

  @override
  State<RepDetailPage> createState() => _RepDetailPageState();
}

class _RepDetailPageState extends State<RepDetailPage> {
  static const _presenter = InvestigationPresenter();
  late final AnalysisController _branch;
  late final AnalysisController _scoped;
  late final InvestigationViewData? _viewData;

  @override
  void initState() {
    super.initState();
    final rep = widget.baseController.dataset.salesReps
        .where((item) => item.id == widget.repId)
        .firstOrNull;
    if (rep == null) {
      _branch = _controller(widget.baseController.filters);
      _scoped = _controller(widget.baseController.filters);
      _viewData = null;
      return;
    }
    _branch = _controller(widget.baseController.filters.copyWith(
      branchId: rep.branchId,
      repId: null,
    ));
    _scoped = _controller(widget.baseController.filters.copyWith(
      branchId: rep.branchId,
      repId: rep.id,
    ));
    _viewData = _presenter.rep(scoped: _scoped, branch: _branch);
  }

  AnalysisController _controller(AnalysisFilters filters) => AnalysisController(
        dataset: widget.baseController.dataset,
        validationReport: widget.baseController.validationReport,
        initialFilters: filters,
      );

  @override
  void dispose() {
    _branch.dispose();
    _scoped.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _viewData == null
      ? _NotFound(kind: 'sales rep', id: widget.repId)
      : _InvestigationScaffold(
          viewData: _viewData,
          scopedController: _scoped,
          benchmarkLabel: 'Branch benchmark',
          repNavigation: false,
        );
}

class _InvestigationScaffold extends StatelessWidget {
  const _InvestigationScaffold({
    required this.viewData,
    required this.scopedController,
    required this.benchmarkLabel,
    required this.repNavigation,
  });

  final InvestigationViewData viewData;
  final AnalysisController scopedController;
  final String benchmarkLabel;
  final bool repNavigation;

  @override
  Widget build(BuildContext context) {
    final horizontal = MediaQuery.sizeOf(context).width >= 720 ? 32.0 : 16.0;
    return Scaffold(
      body: SelectionArea(
        child: SingleChildScrollView(
          key: const Key('investigation-scroll'),
          padding: EdgeInsets.fromLTRB(horizontal, 28, horizontal, 56),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1360),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    TextButton(
                        onPressed: () => AppNavigation.go(context, '/',
                            filters: scopedController.filters
                                .copyWith(branchId: null, repId: null)),
                        child: const Text('All branches')),
                    if (!repNavigation)
                      TextButton(
                          onPressed: () => AppNavigation.up(context),
                          child: const Text('Back to branch')),
                    Text(
                        'Data as of ${DashboardPresenter.formatDate(scopedController.results.performance.snapshot)}'),
                  ]),
                  Text(
                      '${DashboardPresenter.formatDate(scopedController.results.performance.start)} – ${DashboardPresenter.formatDate(scopedController.results.performance.end)}'),
                  Text(DashboardPresenter.formatScopeSummary(scopedController),
                      style: Theme.of(context).textTheme.bodyMedium),
                  Text(viewData.title,
                      style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 6),
                  Text(viewData.subtitle,
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 12),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                          onPressed: () => showEvidenceListDialog(
                              context: context,
                              controller: scopedController,
                              title: 'Active opportunities',
                              subtitle:
                                  'Open opportunities in the selected period',
                              leadIds: scopedController.results.pipeline
                                  .map((p) => p.leadId)
                                  .toList(),
                              footer:
                                  'Confirm the next contact and expected close date with the assigned representative.'),
                          icon: const Icon(Icons.playlist_add_check),
                          label: const Text(
                              'View / export active opportunities'))),
                  const SizedBox(height: 16),
                  if (repNavigation) ...[
                    TargetPanel(controller: scopedController),
                    const SizedBox(height: 20)
                  ],
                  _Section(
                    title: repNavigation
                        ? 'Why this branch is performing this way'
                        : 'Outcomes and workload',
                    description:
                        'Results use the same period and filters as the $benchmarkLabel.',
                    child: _ComparisonTable(
                      rows: viewData.kpis,
                      benchmarkLabel: benchmarkLabel,
                    ),
                  ),
                  if (repNavigation)
                    _Section(
                      title: 'Sales representatives',
                      description:
                          'Open a representative to investigate stage performance and follow-up opportunities.',
                      child: _ComparisonTable(
                        rows: viewData.reps,
                        benchmarkLabel: 'Outcome context',
                        onRowTap: (repId) {
                          final rep = scopedController.dataset.salesReps
                              .where((item) =>
                                  item.id == repId &&
                                  item.branchId ==
                                      scopedController.filters.branchId)
                              .firstOrNull;
                          if (rep != null) {
                            AppNavigation.go(
                                context, '/rep/${Uri.encodeComponent(rep.id)}',
                                filters: scopedController.filters);
                          }
                        },
                      ),
                    ),
                  _Section(
                    title: 'Journey progression and speed',
                    description:
                        'Stage conversion and median transition time expose where follow-up may need investigation.',
                    child: _ComparisonTable(
                      rows: viewData.funnel,
                      benchmarkLabel: benchmarkLabel,
                    ),
                  ),
                  if (repNavigation) ...[
                    _ResponsivePair(
                      first: _Section(
                        title: 'Source mix and performance',
                        child: _ComparisonTable(
                          rows: viewData.sources,
                          benchmarkLabel: benchmarkLabel,
                        ),
                      ),
                      second: _Section(
                        title: 'Model mix and performance',
                        child: _ComparisonTable(
                          rows: viewData.vehicles,
                          benchmarkLabel: benchmarkLabel,
                        ),
                      ),
                    ),
                  ],
                  _ResponsivePair(
                    first: _Section(
                      title: 'Lost reasons',
                      description: 'Reasons recorded by the sales team.',
                      child: _ComparisonTable(
                        rows: viewData.lostReasons,
                        benchmarkLabel: 'Context',
                      ),
                    ),
                    second: _Section(
                      title: 'Active pipeline health',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ComparisonTable(
                            rows: viewData.pipeline,
                            benchmarkLabel: benchmarkLabel,
                          ),
                          const SizedBox(height: 12),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            OutlinedButton.icon(
                              onPressed: viewData.staleLeadIds.isEmpty
                                  ? null
                                  : () => _showPipeline(
                                      context,
                                      viewData.staleLeadIds,
                                      'Stale opportunities'),
                              icon: const Icon(Icons.schedule, size: 18),
                              label: Text(
                                  'Review ${viewData.staleLeadIds.length} stale'),
                            ),
                            OutlinedButton.icon(
                              onPressed: viewData.overdueLeadIds.isEmpty
                                  ? null
                                  : () => _showPipeline(
                                      context,
                                      viewData.overdueLeadIds,
                                      'Overdue orders'),
                              icon: const Icon(Icons.flag_outlined, size: 18),
                              label: Text(
                                  'Review ${viewData.overdueLeadIds.length} overdue'),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  _Section(
                    title: 'Delivery health',
                    description:
                        'Delivery duration is based on linked delivery records in this view.',
                    child: _ComparisonTable(
                      rows: viewData.delivery,
                      benchmarkLabel: benchmarkLabel,
                    ),
                  ),
                  _Section(
                    title: repNavigation
                        ? 'Branch-specific findings'
                        : 'Coaching and investigation signals',
                    description:
                        'Review the finding, then open the supporting opportunities.',
                    child: _InsightList(
                      insights: viewData.insights,
                      onTap: (insight) => showEvidenceListDialog(
                        context: context,
                        controller: scopedController,
                        title: insight.title,
                        subtitle:
                            '${insight.affectedLeadCount} supporting records',
                        leadIds: insight.affectedLeadIds,
                        footer: insight.suggestedInvestigation,
                        inclusionReason: insight.finding,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPipeline(BuildContext context, List<String> ids, String title) {
    final records = {
      for (final item in scopedController.results.pipeline) item.leadId: item
    };
    showEvidenceListDialog(
      context: context,
      controller: scopedController,
      title: title,
      subtitle: '${ids.length} active opportunities',
      leadIds: ids,
      footer:
          'These are attention signals only; active opportunities are not classified as failed outcomes.',
      inclusionReasons: {
        for (final id in ids)
          id: records[id]?.isOverdueOrderStage == true
              ? 'this order-stage opportunity is overdue and has had no recorded activity for ${records[id]!.inactivityDays} days'
              : 'this active opportunity has had no recorded activity for ${records[id]?.inactivityDays ?? 0} days',
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.description});
  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            if (description != null) ...[
              const SizedBox(height: 5),
              Text(description!, style: Theme.of(context).textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({
    required this.rows,
    required this.benchmarkLabel,
    this.onRowTap,
  });
  final List<ComparisonRow> rows;
  final String benchmarkLabel;
  final ValueChanged<String>? onRowTap;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(22),
          child: Text('No records are available for this section.'),
        ),
      );
    }
    if (MediaQuery.sizeOf(context).width < 720) {
      return Card(
          child: Column(
              children: rows
                  .map((row) => InkWell(
                        onTap: onRowTap == null
                            ? null
                            : () => onRowTap!(row.id ?? row.label),
                        child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(children: [
                                    Expanded(
                                        child: Text(row.label,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium)),
                                    if (onRowTap != null)
                                      const Icon(Icons.chevron_right, size: 18)
                                  ]),
                                  Text(row.scoped,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge),
                                  Text('$benchmarkLabel: ${row.benchmark}'),
                                ])),
                      ))
                  .toList()));
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: context.colors.canvas,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Expanded(flex: 50, child: Text('Measure')),
                const Expanded(
                  flex: 25,
                  child: Text('Current view', textAlign: TextAlign.right),
                ),
                Expanded(
                  flex: 25,
                  child: Text(benchmarkLabel, textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
          ...rows.indexed.map(
            (item) => _ComparisonTableRow(
              row: item.$2,
              onTap: onRowTap == null
                  ? null
                  : () => onRowTap!(item.$2.id ?? item.$2.label),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonTableRow extends StatefulWidget {
  const _ComparisonTableRow({required this.row, this.onTap});

  final ComparisonRow row;
  final VoidCallback? onTap;

  @override
  State<_ComparisonTableRow> createState() => _ComparisonTableRowState();
}

class _ComparisonTableRowState extends State<_ComparisonTableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      color: _hovered ? context.colors.infoSoft : context.colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Expanded(
            flex: 50,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.row.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (widget.onTap != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right,
                      size: 18, color: context.colors.muted),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 25,
            child: Text(
              widget.row.scoped,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 25,
            child: Text(
              widget.row.benchmark,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
    if (widget.onTap == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.colors.border)),
        ),
        child: row,
      );
    }
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.colors.border)),
          ),
          child: row,
        ),
      ),
    );
  }
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.first, required this.second});
  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 920
            ? Column(children: [first, second])
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: first),
                  const SizedBox(width: 16),
                  Expanded(child: second),
                ],
              ),
      );
}

class _InsightList extends StatelessWidget {
  const _InsightList({required this.insights, required this.onTap});
  final List<ManagementInsight> insights;
  final ValueChanged<ManagementInsight> onTap;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(22),
          child: Text('No findings meet the review thresholds for this view.'),
        ),
      );
    }
    return Card(
      child: Column(
        children: insights
            .map((insight) => ListTile(
                  title: Text(insight.title),
                  subtitle: Text(
                      '${insight.finding}\n${insight.affectedLeadCount} records · ${insight.evidenceStrength.name} evidence'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onTap(insight),
                ))
            .toList(growable: false),
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.kind, required this.id});
  final String kind;
  final String id;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off, size: 40),
                  const SizedBox(height: 12),
                  Text('Unknown $kind',
                      style: Theme.of(context).textTheme.headlineSmall),
                  Text('No record matches “$id”.'),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () => AppNavigation.go(context, '/'),
                    child: const Text('Return to overview'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
