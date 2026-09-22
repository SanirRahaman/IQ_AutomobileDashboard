import '../shared/target_panel.dart';
import 'target_breakdown_dialog.dart';
import '../../app/analysis_router.dart';
import 'package:flutter/material.dart';

import '../../application/analysis/analysis_controller.dart';
import '../../application/analysis/analysis_filters.dart';
import '../../app/app_theme.dart';
import '../../insights/models/management_insight.dart';
import '../investigation/lead_evidence_dialog.dart';
import 'dashboard_view_data.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.controller});

  final AnalysisController controller;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const _presenter = DashboardPresenter();
  late DashboardViewData _viewData;
  late DateTime _firstDate;
  late DateTime _lastDate;

  @override
  void initState() {
    super.initState();
    _viewData = _presenter.present(widget.controller);
    final dates = <DateTime>[
      ...widget.controller.dataset.leads.map((lead) => lead.createdAt),
      ...widget.controller.dataset.deliveries
          .map((delivery) => delivery.deliveryDate),
    ]..sort();
    _firstDate = dates.isEmpty ? DateTime.now() : dates.first;
    _lastDate = dates.isEmpty ? DateTime.now() : dates.last;
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_refresh);
    _viewData = _presenter.present(widget.controller);
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _viewData = _presenter.present(widget.controller));
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = MediaQuery.sizeOf(context).width >= 720 ? 32.0 : 16.0;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ProductBar(scopeLabel: _viewData.scopeLabel),
            _FilterBar(
              controller: widget.controller,
              dateLabel: _viewData.dateLabel,
              onDatePressed: _chooseDateRange,
              onMorePressed: _showAdvancedFilters,
            ),
            Expanded(
              child: SelectionArea(
                child: SingleChildScrollView(
                  key: const Key('dashboard-scroll'),
                  padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 32),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: 16,
                              runSpacing: 6,
                              children: [
                                Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Sales performance',
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall),
                                      Text(_viewData.scopeLabel),
                                    ]),
                                Tooltip(
                                    message:
                                        'Latest recorded lead, activity, status, order or delivery event. Ages and overdue alerts use this date, not today.',
                                    child: Text(
                                        'Data as of ${DashboardPresenter.formatDate(widget.controller.results.performance.snapshot)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium)),
                              ]),
                          const SizedBox(height: 12),
                          _PulseGrid(
                              metrics: _viewData.pulse,
                              onPressed: _showMetricRecords),
                          const SizedBox(height: 10),
                          Wrap(spacing: 8, runSpacing: 4, children: [
                            TextButton.icon(
                                onPressed: () =>
                                    AppNavigation.go(context, '/pipeline'),
                                icon: const Icon(Icons.playlist_add_check,
                                    size: 18),
                                label: const Text('Active opportunities')),
                            TextButton.icon(
                                onPressed: () =>
                                    AppNavigation.go(context, '/delivery'),
                                icon: const Icon(Icons.local_shipping_outlined,
                                    size: 18),
                                label: const Text('Delivery performance')),
                            if (widget.controller.filters.branchId != null)
                              TextButton.icon(
                                  onPressed: () => AppNavigation.go(context,
                                      '/branch/${Uri.encodeComponent(widget.controller.filters.branchId!)}'),
                                  icon: const Icon(Icons.groups_outlined,
                                      size: 18),
                                  label: const Text(
                                      'Review branch & representatives')),
                            if (widget.controller.filters.repId != null)
                              TextButton(
                                  onPressed: () => AppNavigation.go(context,
                                      '/rep/${Uri.encodeComponent(widget.controller.filters.repId!)}'),
                                  child: const Text('Review representative')),
                            if (widget
                                .controller.validationReport.issues.isNotEmpty)
                              TextButton.icon(
                                  onPressed: _showDataQuality,
                                  icon: const Icon(Icons.warning_amber_rounded,
                                      size: 18, color: AppColors.warning),
                                  label: Text(
                                      '${widget.controller.validationReport.issues.length} data-quality notices')),
                          ]),
                          const SizedBox(height: 8),
                          _ResponsivePair(
                            first: TargetPanel(controller: widget.controller),
                            second: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text('What needs attention',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge),
                                  const SizedBox(height: 8),
                                  _AttentionGrid(
                                      insights:
                                          _viewData.insights.take(3).toList(),
                                      onInvestigate: _showInsightEvidence),
                                  if (_viewData.insights.length > 3)
                                    ExpansionTile(
                                        title: Text(
                                            '${_viewData.insights.length - 3} more findings'),
                                        children: [
                                          _AttentionGrid(
                                              insights: _viewData.insights
                                                  .skip(3)
                                                  .toList(),
                                              onInvestigate:
                                                  _showInsightEvidence)
                                        ]),
                                ]),
                          ),
                          const SizedBox(height: 24),
                          if (!_viewData.hasResults)
                            _NoResultsState(onReset: widget.controller.reset)
                          else ...[
                            const _SectionHeading(
                              eyebrow: 'SALES JOURNEY',
                              title: 'Where opportunities progress or leave',
                              description:
                                  'Follow leads from first contact to delivery. Active leads are not losses.',
                            ),
                            const SizedBox(height: 14),
                            _JourneyPanel(
                              stages: _viewData.journey,
                              onStagePressed: _showStageEvidence,
                            ),
                            const SizedBox(height: 36),
                            const _SectionHeading(
                              eyebrow: 'BRANCH PERFORMANCE',
                              title: 'How branch health differs',
                              description:
                                  'Compare outcomes and follow-up; open a branch to review its representatives.',
                            ),
                            const SizedBox(height: 14),
                            _BranchPanel(
                              branches: _viewData.branches,
                              onBranchPressed: (id) {
                                if (id != null) {
                                  AppNavigation.go(context,
                                      '/branch/${Uri.encodeComponent(id)}');
                                }
                              },
                            ),
                            const SizedBox(height: 36),
                            _ResponsivePair(
                              first: _DiagnosticPanel(
                                title: 'Lead sources',
                                subtitle:
                                    'Volume, contact, resolved, and post-contact performance.',
                                child: _SourceTable(
                                  rows: _viewData.sources,
                                  onPressed: widget.controller.setSource,
                                ),
                              ),
                              second: _DiagnosticPanel(
                                title: 'Vehicle demand and sales',
                                subtitle:
                                    'Demand share, conversion, and delivered-value contribution.',
                                child: _VehicleTable(
                                  rows: _viewData.vehicles,
                                  onPressed: widget.controller.setVehicleModel,
                                ),
                              ),
                            ),
                            const SizedBox(height: 36),
                            _ResponsivePair(
                              first: _DiagnosticPanel(
                                title: 'Conversion by lead month',
                                subtitle:
                                    'Grouped by when leads arrived. Recent groups may still be progressing.',
                                child: _CohortTable(rows: _viewData.cohorts),
                              ),
                              second: _OperationsPanel(
                                data: _viewData.operations,
                                onPipelinePressed: () =>
                                    AppNavigation.go(context, '/pipeline'),
                                onDeliveryPressed: () =>
                                    AppNavigation.go(context, '/delivery'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDataQuality() {
    showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Data-quality notices'),
                content: SizedBox(
                    width: 560,
                    child: SingleChildScrollView(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text(
                              'Source records are unchanged. Review these notices before relying on affected fields.'),
                          const SizedBox(height: 12),
                          ...widget.controller.validationReport.issues.map(
                              (issue) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Text(
                                      '${issue.severity.name.toUpperCase()} · ${issue.message}'))),
                        ]))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Close'))
                ]));
  }

  void _showMetricRecords(PulseMetricViewData metric) {
    final results = widget.controller.results;
    if (metric.kind == PulseMetricKind.target) {
      showTargetBreakdownDialog(
          context: context, performance: results.performance);
      return;
    }
    final ids = switch (metric.kind) {
      PulseMetricKind.enquiries => results.receivedLeadIds,
      PulseMetricKind.active => results.activeLeadIds,
      PulseMetricKind.attention => results.followUpLeadIds,
      PulseMetricKind.conversion => results.deliveredOutcomeIds,
      PulseMetricKind.delivered || PulseMetricKind.deliveredValue => results
          .performance.deliveryRecords
          .map((d) => d.leadId)
          .toList(growable: false),
      PulseMetricKind.target => const <String>[],
    };
    final isDelivery = metric.kind == PulseMetricKind.delivered ||
        metric.kind == PulseMetricKind.deliveredValue;
    showEvidenceListDialog(
      context: context,
      controller: widget.controller,
      title: metric.label,
      subtitle: metric.kind == PulseMetricKind.conversion
          ? '${metric.value} = ${results.overview.delivered} delivered ÷ ${results.overview.resolvedLeads} resolved. ${results.overview.activeLeads} active opportunities excluded.'
          : '${metric.value} · ${_viewData.scopeLabel} · ${_viewData.dateLabel}',
      leadIds: ids,
      footer: metric.helper,
      inclusionReason: isDelivery
          ? 'this delivery occurred within the selected period and filters'
          : null,
      deliveries: isDelivery ? results.performance.deliveryRecords : null,
      groups: metric.kind == PulseMetricKind.conversion
          ? {
              'Delivered': results.deliveredOutcomeIds,
              'Lost': results.lostOutcomeIds
            }
          : const {},
    );
  }

  Future<void> _chooseDateRange() async {
    final current = widget.controller.filters.dateRange;
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(_firstDate.year, _firstDate.month, _firstDate.day),
      lastDate: DateTime(_lastDate.year, _lastDate.month, _lastDate.day),
      initialDateRange: current == null ||
              current.start.isBefore(_firstDate) ||
              current.end.isAfter(_lastDate)
          ? null
          : DateTimeRange(start: current.start, end: current.end),
      helpText: 'Choose analysis period',
      saveText: 'Apply period',
    );
    if (result != null) {
      widget.controller.setDateRange(
        AnalysisDateRange(start: result.start, end: result.end),
      );
    }
  }

  Future<void> _showAdvancedFilters() async {
    final result = await showModalBottomSheet<AnalysisFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AdvancedFiltersSheet(
        controller: widget.controller,
      ),
    );
    if (result != null) widget.controller.replaceFilters(result);
  }

  void _showInsightEvidence(ManagementInsight insight) {
    _showEvidenceDialog(
      title: insight.title,
      subtitle:
          '${insight.affectedLeadCount} supporting records · ${insight.evidenceStrength.name} evidence',
      ids: insight.affectedLeadIds,
      footer: insight.suggestedInvestigation,
      inclusionReason: insight.finding,
    );
  }

  void _showStageEvidence(JourneyStageViewData stage) {
    _showEvidenceDialog(
      title: 'Losses attributed after ${stage.label}',
      subtitle: stage.leakage,
      ids: stage.leakedLeadIds,
      footer:
          'Review these records to understand the transition; the dashboard does not infer cause.',
      inclusionReason:
          'the lead was lost after reaching ${stage.label.toLowerCase()}',
    );
  }

  void _showEvidenceDialog({
    required String title,
    required String subtitle,
    required List<String> ids,
    required String footer,
    String? inclusionReason,
    Map<String, String> inclusionReasons = const {},
  }) {
    showEvidenceListDialog(
      context: context,
      controller: widget.controller,
      title: title,
      subtitle: subtitle,
      leadIds: ids,
      footer: footer,
      inclusionReason: inclusionReason,
      inclusionReasons: inclusionReasons,
    );
  }
}

class _ProductBar extends StatelessWidget {
  const _ProductBar({required this.scopeLabel});

  final String scopeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: AppColors.ink,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, //todo check
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.directions_car_filled,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text(
            'yoyotaDealers',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          // const Spacer(),
          Flexible(
            child: Text(
              scopeLabel,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFB9C0CB),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.controller,
    required this.dateLabel,
    required this.onDatePressed,
    required this.onMorePressed,
  });

  final AnalysisController controller;
  final String dateLabel;
  final VoidCallback onDatePressed;
  final VoidCallback onMorePressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              key: const Key('date-filter'),
              onPressed: onDatePressed,
              icon: const Icon(Icons.calendar_today_outlined, size: 17),
              label: Text(dateLabel),
            ),
            PopupMenuButton<DateTime>(
              tooltip: 'Choose a calendar month',
              onSelected: (month) => controller.setDateRange(AnalysisDateRange(
                  start: month,
                  end: DateTime.utc(month.year, month.month + 1, 0))),
              itemBuilder: (_) {
                final months = {
                  ...controller.dataset.leads.map(
                      (l) => DateTime.utc(l.createdAt.year, l.createdAt.month)),
                  ...controller.dataset.deliveries.map((d) =>
                      DateTime.utc(d.deliveryDate.year, d.deliveryDate.month))
                }.toList()
                  ..sort();
                return months
                    .map((m) => PopupMenuItem(
                        value: m,
                        child: Text(DashboardPresenter.formatMonth(m))))
                    .toList();
              },
              child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Month'),
                    Icon(Icons.arrow_drop_down, size: 18)
                  ])),
            ),
            SizedBox(
              width: 230,
              child: DropdownButtonFormField<String?>(
                key: ValueKey('branch-filter-${controller.filters.branchId}'),
                value: controller.filters.branchId,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.store_outlined, size: 19),
                  prefixIconConstraints: BoxConstraints(minWidth: 38),
                ),
                hint: const Text('All branches'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All branches'),
                  ),
                  ...controller.dataset.branches
                      .map((branch) => DropdownMenuItem<String?>(
                            value: branch.id,
                            child: Text(branch.name,
                                overflow: TextOverflow.ellipsis),
                          )),
                ],
                onChanged: controller.setBranch,
              ),
            ),
            if (controller.filters.branchId != null)
              SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String?>(
                      key: ValueKey(
                          'rep-${controller.filters.branchId}-${controller.filters.repId}'),
                      value: controller.filters.repId,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Representative'),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('All representatives')),
                        ...controller.availableSalesReps.map((r) =>
                            DropdownMenuItem<String?>(
                                value: r.id,
                                child: Text(r.name,
                                    overflow: TextOverflow.ellipsis)))
                      ],
                      onChanged: controller.setSalesRep)),
            OutlinedButton.icon(
              key: const Key('more-filters'),
              onPressed: onMorePressed,
              icon: const Icon(Icons.tune, size: 18),
              label: Text(controller.filters.isDefault
                  ? 'More filters'
                  : 'More filters · Active'),
            ),
            if (!controller.filters.isDefault)
              TextButton.icon(
                key: const Key('reset-filters'),
                onPressed: controller.reset,
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('Reset'),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.description,
  });

  final String eyebrow;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: AppColors.brand,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 5),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 5),
        Text(description, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _PulseGrid extends StatelessWidget {
  const _PulseGrid({required this.metrics, required this.onPressed});

  final List<PulseMetricViewData> metrics;
  final ValueChanged<PulseMetricViewData> onPressed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1180
          ? 6
          : constraints.maxWidth >= 660
              ? 3
              : constraints.maxWidth >= 320
                  ? 2
                  : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: metrics
            .map((metric) => SizedBox(
                  width: width,
                  child: _PulseCard(
                      metric: metric, onPressed: () => onPressed(metric)),
                ))
            .toList(),
      );
    });
  }
}

class _PulseCard extends StatelessWidget {
  const _PulseCard({required this.metric, required this.onPressed});
  final PulseMetricViewData metric;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          key: Key('kpi-${metric.kind.name}'),
          onTap: onPressed,
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(metric.label,
                              style: Theme.of(context).textTheme.bodyMedium)),
                      Tooltip(
                          message: metric.helper,
                          child: IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 24, minHeight: 24),
                              tooltip: metric.helper,
                              onPressed: () => showDialog<void>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                          title: Text(metric.label),
                                          content: Text(metric.helper),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(c),
                                                child: const Text('Close'))
                                          ])),
                              icon: const Icon(Icons.info_outline, size: 15)))
                    ]),
                    const SizedBox(height: 4),
                    Text(metric.value,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                        metric.kind == PulseMetricKind.target
                            ? 'View breakdown →'
                            : 'View records →',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: AppColors.info)),
                  ]))));
}

class _AttentionGrid extends StatelessWidget {
  const _AttentionGrid({
    required this.insights,
    required this.onInvestigate,
  });

  final List<ManagementInsight> insights;
  final ValueChanged<ManagementInsight> onInvestigate;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return const Card(
        child: _InlineEmptyState(
          message: 'No findings meet the review thresholds for this view.',
        ),
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      const columns = 1;
      final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: insights
            .map((insight) => SizedBox(
                  width: width,
                  child: _InsightCard(
                    insight: insight,
                    onPressed: () => onInvestigate(insight),
                  ),
                ))
            .toList(),
      );
    });
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight, required this.onPressed});

  final ManagementInsight insight;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final (color, soft) = switch (insight.severity) {
      InsightSeverity.critical => (AppColors.brand, AppColors.brandSoft),
      InsightSeverity.warning => (AppColors.warning, AppColors.warningSoft),
      InsightSeverity.opportunity => (AppColors.info, AppColors.infoSoft),
      InsightSeverity.positive => (AppColors.positive, AppColors.positiveSoft),
      InsightSeverity.informational => (AppColors.muted, AppColors.canvas),
    };
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    color: soft,
                    child: Text(insight.severity.name.toUpperCase(),
                        style: TextStyle(
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.w700))),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(insight.title,
                        style: Theme.of(context).textTheme.titleMedium)),
                Tooltip(
                    message:
                        '${insight.businessSignificance}\n${insight.evidenceStrength.name} evidence. ${insight.generationReason}',
                    child: const Icon(Icons.info_outline,
                        size: 16, color: AppColors.muted)),
              ]),
              const SizedBox(height: 6),
              Text(insight.finding),
              const SizedBox(height: 6),
              Text('Next: ${insight.suggestedInvestigation}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.ink)),
              TextButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text(
                      'View ${insight.affectedLeadCount} supporting records')),
            ])));
  }
}

class _JourneyPanel extends StatelessWidget {
  const _JourneyPanel({required this.stages, required this.onStagePressed});

  final List<JourneyStageViewData> stages;
  final ValueChanged<JourneyStageViewData> onStagePressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth < 760) {
            return Column(
              children: stages
                  .map((stage) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _JourneyStage(
                          stage: stage,
                          horizontal: true,
                          onPressed: () => onStagePressed(stage),
                        ),
                      ))
                  .toList(),
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < stages.length; index++) ...[
                Expanded(
                  child: _JourneyStage(
                    stage: stages[index],
                    horizontal: false,
                    onPressed: () => onStagePressed(stages[index]),
                  ),
                ),
                if (index < stages.length - 1)
                  const Padding(
                    padding: EdgeInsets.only(top: 34),
                    child: Icon(Icons.arrow_forward,
                        size: 16, color: AppColors.muted),
                  ),
              ],
            ],
          );
        }),
      ),
    );
  }
}

class _JourneyStage extends StatelessWidget {
  const _JourneyStage({
    required this.stage,
    required this.horizontal,
    required this.onPressed,
  });

  final JourneyStageViewData stage;
  final bool horizontal;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(12),
      child: horizontal
          ? Row(
              children: [
                _count(context),
                const SizedBox(width: 14),
                Expanded(child: _labels(context)),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _count(context),
                const SizedBox(height: 10),
                _labels(context),
              ],
            ),
    );
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      hoverColor: AppColors.canvas,
      child: content,
    );
  }

  Widget _count(BuildContext context) => Text(
        DashboardPresenter.formatInteger(stage.count),
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24),
      );

  Widget _labels(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(stage.label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(stage.progression,
              style: Theme.of(context).textTheme.bodyMedium),
          Text(
            stage.leakage,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: stage.leakedLeadIds.isEmpty
                      ? AppColors.muted
                      : AppColors.warning,
                ),
          ),
        ],
      );
}

class _BranchPanel extends StatelessWidget {
  const _BranchPanel({required this.branches, required this.onBranchPressed});

  final List<BranchDiagnosticViewData> branches;
  final ValueChanged<String?> onBranchPressed;

  @override
  Widget build(BuildContext context) {
    if (branches.isEmpty) {
      return const Card(
        child: _InlineEmptyState(message: 'No branch records in this view.'),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            children: branches
                .map((branch) => _BranchCompactRow(
                      branch: branch,
                      onPressed: () => onBranchPressed(branch.id),
                    ))
                .toList(growable: false),
          );
        }
        return Column(
          children: [
            Container(
              color: AppColors.canvas,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              child: const Row(children: [
                Expanded(flex: 26, child: Text('Branch')),
                Expanded(
                    flex: 12, child: Text('Leads', textAlign: TextAlign.right)),
                Expanded(
                    flex: 20,
                    child:
                        Text('Resolved outcomes', textAlign: TextAlign.right)),
                Expanded(
                    flex: 15,
                    child: Text('Conversion', textAlign: TextAlign.right)),
                Expanded(
                    flex: 15,
                    child: Text('Active value', textAlign: TextAlign.right)),
                Expanded(
                    flex: 24,
                    child:
                        Text('Lowest progression', textAlign: TextAlign.right)),
                SizedBox(width: 22),
              ]),
            ),
            ...branches.map((branch) => _BranchWideRow(
                  branch: branch,
                  onPressed: () => onBranchPressed(branch.id),
                )),
          ],
        );
      }),
    );
  }
}

class _BranchWideRow extends StatefulWidget {
  const _BranchWideRow({required this.branch, required this.onPressed});

  final BranchDiagnosticViewData branch;
  final VoidCallback onPressed;

  @override
  State<_BranchWideRow> createState() => _BranchWideRowState();
}

class _BranchWideRowState extends State<_BranchWideRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        color: _hovered ? AppColors.infoSoft : AppColors.surface,
        child: InkWell(
          onTap: widget.onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(children: [
              Expanded(
                  flex: 26,
                  child: Text(widget.branch.name,
                      style: const TextStyle(fontWeight: FontWeight.w600))),
              Expanded(
                  flex: 12,
                  child: Text(widget.branch.leadVolume,
                      textAlign: TextAlign.right, style: textStyle)),
              Expanded(
                  flex: 20,
                  child: Text(widget.branch.outcomes,
                      textAlign: TextAlign.right, style: textStyle)),
              Expanded(
                  flex: 15,
                  child: Text(widget.branch.conversion,
                      textAlign: TextAlign.right, style: textStyle)),
              Expanded(
                  flex: 15,
                  child: Text(widget.branch.activeValue,
                      textAlign: TextAlign.right, style: textStyle)),
              Expanded(
                  flex: 24,
                  child: Text(widget.branch.bottleneck,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: textStyle)),
              const SizedBox(
                  width: 22,
                  child: Icon(Icons.chevron_right,
                      size: 18, color: AppColors.muted)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _BranchCompactRow extends StatelessWidget {
  const _BranchCompactRow({required this.branch, required this.onPressed});

  final BranchDiagnosticViewData branch;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(branch.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 5),
                    Text(
                        '${branch.leadVolume} leads · ${branch.outcomes} resolved · ${branch.conversion}',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 3),
                    Text(
                        'Active value ${branch.activeValue} · ${branch.bottleneck}',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ]),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
          ]),
        ),
      );
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 920) {
        return Column(
          children: [first, const SizedBox(height: 16), second],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          const SizedBox(width: 16),
          Expanded(child: second),
        ],
      );
    });
  }
}

class _DiagnosticPanel extends StatelessWidget {
  const _DiagnosticPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }
}

class _DashboardTable extends StatelessWidget {
  const _DashboardTable({
    required this.headers,
    required this.rows,
    required this.flexes,
    required this.onTap,
  });

  final List<String> headers;
  final List<List<Widget>> rows;
  final List<int> flexes;
  final List<VoidCallback?> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 560) {
        return Column(
          children: rows.indexed
              .map((item) => _DashboardCompactRow(
                    headers: headers,
                    cells: item.$2,
                    onTap: onTap[item.$1],
                  ))
              .toList(growable: false),
        );
      }
      return Column(
        children: [
          _DashboardTableRow(
            cells:
                headers.map((header) => Text(header)).toList(growable: false),
            flexes: flexes,
            header: true,
          ),
          ...rows.indexed.map((item) => _DashboardTableRow(
                cells: item.$2,
                flexes: flexes,
                onTap: onTap[item.$1],
              )),
        ],
      );
    });
  }
}

class _DashboardTableRow extends StatelessWidget {
  const _DashboardTableRow({
    required this.cells,
    required this.flexes,
    this.header = false,
    this.onTap,
  });

  final List<Widget> cells;
  final List<int> flexes;
  final bool header;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      // color: header ? AppColors.canvas : AppColors.surface,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: header ? 12 : 13),
      decoration: header
          ? null
          : const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
      child: Row(
        children: cells.indexed
            .map((item) => Expanded(
                  flex: flexes[item.$1],
                  child: SizedBox(
                    width: double.infinity,
                    child: Align(
                      alignment: item.$1 == 0
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: item.$2,
                    ),
                  ),
                ))
            .toList(growable: false),
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

class _DashboardCompactRow extends StatelessWidget {
  const _DashboardCompactRow({
    required this.headers,
    required this.cells,
    required this.onTap,
  });

  final List<String> headers;
  final List<Widget> cells;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          cells.first,
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 5,
            children: cells.indexed.skip(1).map((item) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${headers[item.$1]}: ',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.muted,
                          )),
                  Flexible(child: item.$2),
                ],
              );
            }).toList(growable: false),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

class _SourceTable extends StatelessWidget {
  const _SourceTable({required this.rows, required this.onPressed});

  final List<SourceDiagnosticViewData> rows;
  final ValueChanged<String?> onPressed;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _InlineEmptyState(message: 'No source data in this view.');
    }
    return _DashboardTable(
      headers: const [
        'Source',
        'Volume',
        'Contact',
        'Resolved',
        'Post-contact'
      ],
      flexes: const [25, 15, 20, 20, 20],
      rows: rows
          .map((row) => [
                Text(row.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(row.volume),
                Text(row.contactRate),
                Text(row.resolvedConversion),
                Text(row.postContactRate),
              ])
          .toList(growable: false),
      onTap: rows
          .map((row) => row.id == null ? null : () => onPressed(row.id))
          .toList(growable: false),
    );
  }
}

class _VehicleTable extends StatelessWidget {
  const _VehicleTable({required this.rows, required this.onPressed});

  final List<VehicleDiagnosticViewData> rows;
  final ValueChanged<String> onPressed;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _InlineEmptyState(message: 'No vehicle data in this view.');
    }
    return _DashboardTable(
      headers: const [
        'Model',
        'Demand',
        'Conversion',
        'Value share',
        'Delivered value'
      ],
      flexes: const [27, 17, 19, 18, 19],
      rows: rows
          .map((row) => [
                Text(row.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(row.demandShare),
                Text(row.conversion),
                Text(row.deliveredValueShare),
                Text(row.deliveredValue),
              ])
          .toList(growable: false),
      onTap: rows.map((row) => () => onPressed(row.id)).toList(growable: false),
    );
  }
}

class _CohortTable extends StatelessWidget {
  const _CohortTable({required this.rows});

  final List<CohortViewData> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _InlineEmptyState(
          message: 'No leads received in this period.');
    }
    return _DashboardTable(
      headers: const [
        'Month',
        'Leads',
        'Delivered',
        'Lost',
        'Active',
        'Conversion'
      ],
      flexes: const [30, 14, 14, 12, 12, 18],
      rows: rows
          .map((row) => [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(row.month,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: row.isMature
                            ? AppColors.positiveSoft
                            : AppColors.warningSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        row.isMature ? 'Mature' : 'Immature',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: row.isMature
                              ? AppColors.positive
                              : AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                Text('${row.volume}'),
                Text('${row.delivered}'),
                Text('${row.lost}'),
                Text('${row.active}'),
                Text(row.conversion),
              ])
          .toList(growable: false),
      onTap: rows.map((_) => null).toList(growable: false),
    );
  }
}

class _OperationsPanel extends StatelessWidget {
  const _OperationsPanel({
    required this.data,
    required this.onPipelinePressed,
    required this.onDeliveryPressed,
  });

  final OperationsViewData data;
  final VoidCallback onPipelinePressed;
  final VoidCallback onDeliveryPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pipeline & delivery health',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Compact operational signals for the current view.',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 18),
            _OperationsRow(
              icon: Icons.track_changes,
              title: 'Active pipeline',
              value: '${data.activeCount} · ${data.activeValue}',
              detail:
                  '${data.staleCount} stale · ${data.overdueOrderCount} overdue orders',
              onPressed: onPipelinePressed,
            ),
            const Divider(height: 28),
            _OperationsRow(
              icon: Icons.local_shipping_outlined,
              title: 'Delivery execution',
              value: '${data.deliveryCount} deliveries',
              detail:
                  '${data.medianDeliveryDays} median · ${data.p90DeliveryDays} p90',
              onPressed: onDeliveryPressed,
            ),
          ],
        ),
      ),
    );
  }
}

class _OperationsRow extends StatelessWidget {
  const _OperationsRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String value;
  final String detail;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 20, color: AppColors.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(value, style: Theme.of(context).textTheme.bodyLarge),
                  Text(detail, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, size: 17, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _AdvancedFiltersSheet extends StatefulWidget {
  const _AdvancedFiltersSheet({required this.controller});

  final AnalysisController controller;

  @override
  State<_AdvancedFiltersSheet> createState() => _AdvancedFiltersSheetState();
}

class _AdvancedFiltersSheetState extends State<_AdvancedFiltersSheet> {
  late String? _rep;
  late String? _source;
  late String? _model;
  late String? _status;

  @override
  void initState() {
    super.initState();
    final filters = widget.controller.filters;
    _rep = filters.repId;
    _source = filters.source;
    _model = filters.vehicleModel;
    _status = filters.leadStatus;
  }

  @override
  Widget build(BuildContext context) {
    final sources = widget.controller.dataset.leads
        .map((lead) => lead.source)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    final models = widget.controller.dataset.leads
        .map((lead) => lead.modelInterested)
        .toSet()
        .toList()
      ..sort();
    final statuses = widget.controller.dataset.leads
        .map((lead) => lead.status.rawValue)
        .toSet()
        .toList()
      ..sort();
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Additional filters',
                          style: Theme.of(context).textTheme.headlineSmall),
                    ),
                    IconButton(
                      tooltip: 'Close filters',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Narrow the opportunities shown in this view.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 22),
                _FilterDropdown(
                  label: 'Sales representative',
                  value: _rep,
                  allLabel: 'All representatives',
                  options: widget.controller.availableSalesReps
                      .map((rep) => MapEntry(rep.id, rep.name))
                      .toList(),
                  onChanged: (value) => setState(() => _rep = value),
                ),
                const SizedBox(height: 14),
                _FilterDropdown(
                  label: 'Lead source',
                  value: _source,
                  allLabel: 'All sources',
                  options: sources
                      .map((value) =>
                          MapEntry(value, value.replaceAll('_', ' ')))
                      .toList(),
                  onChanged: (value) => setState(() => _source = value),
                ),
                const SizedBox(height: 14),
                _FilterDropdown(
                  label: 'Vehicle model',
                  value: _model,
                  allLabel: 'All models',
                  options:
                      models.map((value) => MapEntry(value, value)).toList(),
                  onChanged: (value) => setState(() => _model = value),
                ),
                const SizedBox(height: 14),
                _FilterDropdown(
                  label: 'Lead status',
                  value: _status,
                  allLabel: 'All statuses',
                  options: statuses
                      .map((value) =>
                          MapEntry(value, value.replaceAll('_', ' ')))
                      .toList(),
                  onChanged: (value) => setState(() => _status = value),
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => setState(() {
                        _rep = null;
                        _source = null;
                        _model = null;
                        _status = null;
                      }),
                      child: const Text('Clear additional filters'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(
                        context,
                        widget.controller.filters.copyWith(
                          repId: _rep,
                          source: _source,
                          vehicleModel: _model,
                          leadStatus: _status,
                        ),
                      ),
                      child: const Text('Apply filters'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.allLabel,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final String allLabel;
  final List<MapEntry<String, String>> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 7),
        DropdownButtonFormField<String?>(
          value: value,
          isExpanded: true,
          items: [
            DropdownMenuItem<String?>(value: null, child: Text(allLabel)),
            ...options.map((entry) => DropdownMenuItem<String?>(
                  value: entry.key,
                  child: Text(entry.value),
                )),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 54),
        child: Column(
          children: [
            const Icon(Icons.filter_alt_off_outlined,
                size: 42, color: AppColors.muted),
            const SizedBox(height: 14),
            Text('No records match these filters',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Broaden the date range or remove one or more filters.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset filters'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Text(message,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center),
      ),
    );
  }
}
