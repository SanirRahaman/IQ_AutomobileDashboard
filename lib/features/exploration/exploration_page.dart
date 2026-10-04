import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../analytics/services/performance_explorer.dart';
import '../../app/app_theme.dart';
import '../../application/analysis/analysis_controller.dart';
import '../dashboard/dashboard_view_data.dart';
import '../investigation/lead_evidence_dialog.dart';
import '../operations/operational_pages.dart';
import '../shared/performance_navigation.dart';
import 'exploration_presenter.dart';

class ExplorationPage extends StatefulWidget {
  const ExplorationPage({
    super.key,
    required this.controller,
    this.section = PerformanceSection.compareModels,
  });
  final AnalysisController controller;
  final PerformanceSection section;
  @override
  State<ExplorationPage> createState() => _ExplorationPageState();
}

class _ExplorationPageState extends State<ExplorationPage> {
  late ComparisonDimension _dimension;
  late ComparisonMetric _metric;
  ComparisonMetric _trendMetric = ComparisonMetric.deliveries;
  late PerformanceExploration _data;
  bool _ascending = false;
  bool _compare = false;
  int _a = 0, _b = 1;
  int _month = 0;
  int? _limit = 5;

  @override
  void initState() {
    super.initState();
    _dimension =
        widget.section.comparisonDimension ?? ComparisonDimension.model;
    _metric = defaultComparisonMetric(_dimension);
    _load();
    widget.controller.addListener(_refresh);
  }

  void _load() {
    _data = widget.controller.explore(_dimension);
    _a = 0;
    _b = _data.rows.length > 1 ? 1 : 0;
    _compare = false;
    _month = math.max(0, _data.months.length - 1);
  }

  @override
  void didUpdateWidget(covariant ExplorationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final requested = widget.section.comparisonDimension;
    if (requested != null && requested != _dimension) {
      _dimension = requested;
      _metric = defaultComparisonMetric(requested);
      _ascending = false;
      _limit = 5;
      _load();
    }
  }

  void _refresh() => setState(_load);
  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _evidence(PerformanceSlice slice, ComparisonMetric metric) {
    showEvidenceListDialog(
        context: context,
        controller: widget.controller,
        title: '${slice.label} · ${metric.label}',
        subtitle:
            '${metric.format(slice.value(metric))} · ${sampleLabel(slice, metric)}',
        leadIds: slice.evidence(metric),
        deliveries: metric.usesDeliveries ? slice.deliveries : null,
        footer: metric.definition,
        inclusionReason: metric.definition);
  }

  @override
  Widget build(BuildContext context) => OperationsScaffold(
      controller: widget.controller,
      title: widget.section.isComparison
          ? 'Compare ${_dimension.label.toLowerCase()}'
          : widget.section == PerformanceSection.trends
              ? 'Monthly performance trends'
              : 'Follow-up lists',
      question: widget.section.isComparison
          ? 'Rank the selected measure, understand its support, and open the records behind each result.'
          : widget.section == PerformanceSection.trends
              ? 'How are supported dealership measures changing across comparable months?'
              : 'Which scoped records should the team verify or act on?',
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (widget.section.isComparison) _comparisons(),
        if (widget.section == PerformanceSection.trends) _trends(),
        if (widget.section == PerformanceSection.followUp) _followUp(),
        const SizedBox(height: 20),
        const Card(
            child: ExpansionTile(
                title: Text('What this data can and cannot tell you'),
                childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
              Text(
                  'All figures describe the supplied extract. Monthly lead outcomes are grouped by lead creation, while sales and delivery durations use delivery dates. Partial months are labelled; recent conversion cohorts may still be progressing.\n\nHistorical active/stale pipeline trends are unavailable: changing the date filter does not reconstruct an earlier pipeline. Current values and inactivity use the dataset snapshot.\n\nRecorded loss and delay reasons identify associations, not proven causes. No overall “best performer” score is assigned. Check sample size before ranking rates.\n\nProfit, customer satisfaction, marketing ROI and forecasts are not supported. Targets currently compare branch-month delivery units only; target revenue requires confirmation of matching value semantics and coverage.'),
            ])),
      ]));

  Widget _comparisons() {
    final ranking = presentComparisonRanking(
        data: _data, metric: _metric, ascending: _ascending);
    final shown = _compare && _data.rows.length >= 2
        ? ranking.rows
            .where((row) =>
                identical(row.slice, _data.rows[_a]) ||
                identical(row.slice, _data.rows[_b]))
            .toList(growable: false)
        : _limit == null
            ? ranking.rows
            : ranking.rows.take(_limit!).toList(growable: false);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _measureTabs(),
      const SizedBox(height: 14),
      Text('${_metric.label} by ${_dimension.label.toLowerCase()}',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 6),
      Text(_metric.definition),
      const SizedBox(height: 6),
      Text(_scopeNote(), style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 12),
      Wrap(
          spacing: 20,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _CompactOptions<bool>(
                label: 'Order',
                value: _ascending,
                values: const [false, true],
                valueLabel: (value) => value ? 'Lowest first' : 'Highest first',
                onChanged: (value) => setState(() => _ascending = value),
                keyPrefix: 'explore-order'),
            _CompactOptions<int>(
                label: 'Show',
                value: _limit ?? 0,
                values: const [5, 10, 0],
                valueLabel: (value) => value == 0 ? 'All' : '$value',
                onChanged: (value) =>
                    setState(() => _limit = value == 0 ? null : value),
                keyPrefix: 'explore-limit'),
            Text(
                '${_data.rows.length} ${_data.rows.length == 1 ? 'group' : 'groups'} · current-view ${_metric.label.toLowerCase()}: ${_metric.format(_data.total.value(_metric))}'),
          ]),
      const SizedBox(height: 10),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Ranking details & compare two'),
        children: [
          Text(ranking.explanation),
          FilterChip(
            label: const Text('Compare two'),
            selected: _compare,
            onSelected: _data.rows.length < 2
                ? null
                : (value) => setState(() => _compare = value),
          ),
          if (_compare && _data.rows.length >= 2)
            Wrap(spacing: 12, runSpacing: 12, children: [
              _select<int>(
                  'First group',
                  _a,
                  List.generate(_data.rows.length, (i) => i),
                  (i) => _data.rows[i].label,
                  (i) => setState(() => _a = i),
                  key: 'compare-a'),
              _select<int>(
                  'Second group',
                  _b,
                  List.generate(_data.rows.length, (i) => i),
                  (i) => _data.rows[i].label,
                  (i) => setState(() => _b = i),
                  key: 'compare-b'),
              const Text(
                  'Ranks and badges refer to the full filtered comparison, not just these two groups.'),
            ]),
        ],
      ),
      const SizedBox(height: 16),
      if (shown.isEmpty) const Text('No groups match the current filters.'),
      if (shown.isNotEmpty)
        Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (final row in shown)
                _ComparisonBar(
                    data: row,
                    value: _metric.format(row.slice.value(_metric)),
                    onTap: row.slice.evidence(_metric).isEmpty
                        ? null
                        : () => _evidence(row.slice, _metric)),
            ])),
    ]);
  }

  Widget _measureTabs() {
    final primary = comparisonMetricsFor(_dimension);
    Widget choices(Iterable<ComparisonMetric> metrics) =>
        Wrap(spacing: 7, runSpacing: 7, children: [
          for (final metric in metrics)
            Tooltip(
              message: metric.definition,
              child: ChoiceChip(
                key: Key('explore-metric-${metric.name}'),
                label: Text(metric.label),
                selected: _metric == metric,
                selectedColor: context.colors.brandSoft,
                onSelected: (_) => setState(() => _metric = metric),
              ),
            ),
        ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Measure', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 7),
      choices(primary),
      ExpansionTile(
        key: ValueKey('more-measures-${_dimension.name}'),
        tilePadding: EdgeInsets.zero,
        title: Text(primary.contains(_metric)
            ? 'More measures'
            : 'More measures · ${_metric.label}'),
        children: [
          choices(ComparisonMetric.values.where((m) => !primary.contains(m)))
        ],
      ),
    ]);
  }

  String _scopeNote() {
    final filters = widget.controller.filters;
    if (_dimension == ComparisonDimension.representative &&
        filters.branchId != null) {
      final branch = widget.controller.dataset.branches
          .where((item) => item.id == filters.branchId)
          .map((item) => item.name)
          .firstOrNull;
      return 'Scope restriction: representatives assigned to ${branch ?? filters.branchId} within the active filters.';
    }
    if (_dimension == ComparisonDimension.representative &&
        filters.repId == null) {
      return 'Representatives are shown with branch context. Select a branch to compare within one team.';
    }
    if (_data.rows.length == 1) {
      return 'Only one comparison group remains in the active filters; rankings need at least two supported results.';
    }
    return 'All rows use the same visible period and active filters.';
  }

  Widget _trends() {
    const metrics = [
      ComparisonMetric.deliveries,
      ComparisonMetric.leads,
      ComparisonMetric.deliveredValue,
      ComparisonMetric.conversion,
      ComparisonMetric.deliveryDays
    ];
    final months = _data.months;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _select<ComparisonMetric>('Monthly measure', _trendMetric, metrics,
          (m) => m.label, (m) => setState(() => _trendMetric = m),
          key: 'trend-metric'),
      const SizedBox(height: 12),
      Text(_trendMetric.definition),
      const SizedBox(height: 12),
      if (months.isEmpty)
        const Text('No months fall within the observed data coverage.'),
      if (months.isNotEmpty)
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('${_trendMetric.label} by month',
                          style: Theme.of(context).textTheme.titleLarge),
                      const Text(
                          'Select a month to inspect its records. Hollow points indicate partial or immature periods; unavailable values are gaps.'),
                      const SizedBox(height: 12),
                      _MonthlyChart(
                          months: months,
                          metric: _trendMetric,
                          selected: _month,
                          onSelected: (i) => setState(() => _month = i)),
                      const SizedBox(height: 12),
                      _select<int>(
                          'Selected month',
                          _month,
                          List.generate(months.length, (i) => i),
                          (i) =>
                              DashboardPresenter.formatMonth(months[i].month),
                          (i) => setState(() => _month = i),
                          key: 'trend-month'),
                      const SizedBox(height: 12),
                      Text(
                          '${DashboardPresenter.formatMonth(months[_month].month)} · ${_trendMetric.format(months[_month].slice.value(_trendMetric))}',
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(
                          '${sampleLabel(months[_month].slice, _trendMetric)}${months[_month].partial ? ' · partial month / extract coverage' : ''}'),
                      Text(_changeLabel(_month)),
                      Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                              onPressed: months[_month]
                                      .slice
                                      .evidence(_trendMetric)
                                      .isEmpty
                                  ? null
                                  : () => _evidence(
                                      months[_month].slice, _trendMetric),
                              icon: const Icon(Icons.list_alt),
                              label: const Text('View month records'))),
                    ]))),
      const SizedBox(height: 12),
      const Text(
          'Active and stale values are available in the sidebar comparison views. Historical pipeline trends are not reconstructed from this extract.'),
    ]);
  }

  String _changeLabel(int month) {
    final change = _data.monthChange(month, _trendMetric);
    if (change == null) {
      return 'Previous-month change unavailable: both months must be complete, observed and, for conversion, mature.';
    }
    final text = _trendMetric.isRate
        ? '${change.toStringAsFixed(1)} percentage points'
        : _trendMetric.format(change);
    return '${change > 0 ? '+' : ''}$text versus ${DashboardPresenter.formatMonth(_data.months[month - 1].month)}';
  }

  Widget _followUp() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text(
            'Open a list, then choose highest value, longest inactivity or most overdue. Sorting helps investigation; it does not assign an automatic priority score.'),
        const SizedBox(height: 12),
        for (final metric in const [
          ComparisonMetric.activeCount,
          ComparisonMetric.staleCount,
          ComparisonMetric.overdueCount,
          ComparisonMetric.lostCount,
          ComparisonMetric.deliveries
        ])
          Card(
              child: ListTile(
                  title: Text(metric.label),
                  subtitle: Text(metric.definition),
                  trailing: Text(metric.format(_data.total.value(metric))),
                  onTap: _data.total.evidence(metric).isEmpty
                      ? null
                      : () => _evidence(_data.total, metric))),
      ]);

  Widget _select<T>(String label, T value, List<T> values,
          String Function(T) name, ValueChanged<T> onChanged,
          {required String key}) =>
      ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: DropdownButtonFormField<T>(
              key: Key(key),
              value: value,
              isExpanded: true,
              decoration: InputDecoration(labelText: label),
              items: values
                  .map((v) => DropdownMenuItem(
                      value: v,
                      child: Text(name(v), overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              }));
}

class _ComparisonBar extends StatelessWidget {
  const _ComparisonBar(
      {required this.data, required this.value, required this.onTap});
  final RankedComparisonViewData data;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (accent, soft) = switch (data.tone) {
      ComparisonRankTone.positive => (
          context.colors.positive,
          context.colors.positiveSoft
        ),
      ComparisonRankTone.attention => (
          context.colors.warning,
          context.colors.warningSoft
        ),
      ComparisonRankTone.neutral => (
          context.colors.info,
          context.colors.infoSoft
        ),
      null => (context.colors.info, context.colors.canvas),
    };
    return InkWell(
        hoverColor: context.colors.canvas,
        focusColor: context.colors.infoSoft,
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                        width: 36,
                        child: Text(
                            data.rank == null
                                ? '—'
                                : data.rankTied
                                    ? '=${data.rank}'
                                    : '#${data.rank}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: context.colors.muted))),
                    Expanded(
                        child: Text(data.slice.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium)),
                    const SizedBox(width: 12),
                    Text(value,
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.titleMedium),
                  ]),
                  if (data.badge != null) ...[
                    const SizedBox(height: 7),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: soft,
                                borderRadius: BorderRadius.circular(999)),
                            child: Text(data.badge!,
                                style: TextStyle(
                                    color: accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)))),
                  ],
                  const SizedBox(height: 8),
                  ExcludeSemantics(
                      child: LinearProgressIndicator(
                          value: data.fraction,
                          minHeight: 5,
                          color: accent,
                          backgroundColor: context.colors.canvas)),
                  const SizedBox(height: 6),
                  Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(data.supportLabel,
                            style: Theme.of(context).textTheme.bodyMedium),
                        if (onTap != null)
                          Text('View supporting records →',
                              style: TextStyle(color: context.colors.info)),
                      ]),
                ])));
  }
}

class _CompactOptions<T> extends StatelessWidget {
  const _CompactOptions({
    required this.label,
    required this.value,
    required this.values,
    required this.valueLabel,
    required this.onChanged,
    required this.keyPrefix,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T) valueLabel;
  final ValueChanged<T> onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('$label:', style: Theme.of(context).textTheme.labelMedium),
          for (final option in values)
            ChoiceChip(
              key: Key('$keyPrefix-$option'),
              visualDensity: VisualDensity.compact,
              label: Text(valueLabel(option)),
              selected: option == value,
              onSelected: (_) => onChanged(option),
            ),
        ],
      );
}

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart(
      {required this.months,
      required this.metric,
      required this.selected,
      required this.onSelected});
  final List<MonthlyPerformance> months;
  final ComparisonMetric metric;
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) {
    final values =
        months.map((m) => m.slice.value(metric)?.toDouble()).toList();
    final qualified = months
        .map((m) =>
            m.partial ||
            (metric == ComparisonMetric.conversion && !m.slice.mature))
        .toList();
    final min = values.whereType<double>().fold<double>(0, math.min);
    final max = values.whereType<double>().fold<double>(0, math.max);
    final top = max == min ? min + 1 : max;
    return SizedBox(
        height: 280,
        child: LayoutBuilder(builder: (context, box) {
          const left = 70.0, right = 20.0, bottom = 40.0, upper = 20.0;
          final width = math.max(1.0, box.maxWidth - left - right);
          const height = 280.0 - upper - bottom;
          final points = List<Offset?>.generate(
              months.length,
              (i) => values[i] == null
                  ? null
                  : Offset(
                      left +
                          (months.length == 1
                              ? width / 2
                              : i * width / (months.length - 1)),
                      upper + height * (1 - (values[i]! - min) / (top - min))));
          final labelEvery =
              math.max(1, (months.length / math.max(2, width / 85)).ceil());
          return Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
                child: CustomPaint(
                    painter: _TrendPainter(
                        colors: context.colors,
                        points: points,
                        qualified: qualified,
                        baseline: upper + height,
                        left: left,
                        right: box.maxWidth - right))),
            Positioned(
                left: 0,
                top: 0,
                width: 64,
                child: Text(metric.format(top), textAlign: TextAlign.right)),
            Positioned(
                left: 0,
                top: upper + height - 12,
                width: 64,
                child: Text(metric.format(min), textAlign: TextAlign.right)),
            for (var i = 0; i < months.length; i++) ...[
              if (points[i] != null)
                Positioned(
                    left: points[i]!.dx - 16,
                    top: points[i]!.dy - 16,
                    child: Tooltip(
                        message:
                            '${DashboardPresenter.formatMonth(months[i].month)}: ${metric.format(values[i])}'
                            '${months[i].partial ? ' · partial' : ''}${metric == ComparisonMetric.conversion && !months[i].slice.mature ? ' · immature' : ''}',
                        child: Semantics(
                            button: true,
                            selected: selected == i,
                            label:
                                '${DashboardPresenter.formatMonth(months[i].month)} ${metric.format(values[i])}',
                            child: InkResponse(
                                onTap: () => onSelected(i),
                                child: SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: Center(
                                        child: Container(
                                            width: selected == i ? 14 : 10,
                                            height: selected == i ? 14 : 10,
                                            decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: qualified[i]
                                                    ? context.colors.surface
                                                    : context.colors.info,
                                                border: Border.all(
                                                    color: context.colors.info,
                                                    width: 2))))))))),
              if (i % labelEvery == 0)
                Positioned(
                    left: left +
                        (months.length == 1
                            ? width / 2
                            : i * width / (months.length - 1)) -
                        32,
                    top: upper + height + 12,
                    width: 64,
                    child: Text(DashboardPresenter.formatMonth(months[i].month),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10))),
            ],
          ]);
        }));
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter(
      {required this.colors,
      required this.points,
      required this.qualified,
      required this.baseline,
      required this.left,
      required this.right});
  final AppPalette colors;
  final List<Offset?> points;
  final List<bool> qualified;
  final double baseline, left, right;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(Offset(left, 20), Offset(left, baseline),
        Paint()..color = colors.border);
    canvas.drawLine(Offset(left, baseline), Offset(right, baseline),
        Paint()..color = colors.border);
    final paint = Paint()
      ..color = colors.info
      ..strokeWidth = 2;
    for (var i = 1; i < points.length; i++) {
      if (points[i - 1] != null && points[i] != null) {
        final from = points[i - 1]!, to = points[i]!;
        if (qualified[i - 1] || qualified[i]) {
          final distance = (to - from).distance;
          for (var at = 0.0; at < distance; at += 10) {
            canvas.drawLine(
                Offset.lerp(from, to, at / distance)!,
                Offset.lerp(from, to, math.min(at + 5, distance) / distance)!,
                paint);
          }
        } else {
          canvas.drawLine(from, to, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.right != right ||
      oldDelegate.colors.dark != colors.dark;
}
