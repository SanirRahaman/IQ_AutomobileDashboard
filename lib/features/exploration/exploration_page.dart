import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../analytics/services/performance_explorer.dart';
import '../../app/app_theme.dart';
import '../../application/analysis/analysis_controller.dart';
import '../dashboard/dashboard_view_data.dart';
import '../investigation/lead_evidence_dialog.dart';
import '../operations/operational_pages.dart';
import 'exploration_presenter.dart';

class ExplorationPage extends StatefulWidget {
  const ExplorationPage({super.key, required this.controller});
  final AnalysisController controller;
  @override
  State<ExplorationPage> createState() => _ExplorationPageState();
}

class _ExplorationPageState extends State<ExplorationPage> {
  ComparisonDimension _dimension = ComparisonDimension.model;
  ComparisonMetric _metric = ComparisonMetric.deliveries;
  ComparisonMetric _trendMetric = ComparisonMetric.deliveries;
  late PerformanceExploration _data;
  bool _ascending = false;
  bool _compare = false;
  int _a = 0, _b = 1;
  int _tab = 0;
  int _month = 0;
  int? _limit = 5;

  @override
  void initState() {
    super.initState();
    _load();
    widget.controller.addListener(_refresh);
  }

  void _load() {
    _data = widget.controller.explore(_dimension);
    _a = 0;
    _b = _data.rows.length > 1 ? 1 : 0;
    _month = math.max(0, _data.months.length - 1);
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
      title: 'Explore performance',
      question:
          'Compare the measure that matters, follow its trend, then open the supporting records.',
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
            const DashboardPresenter().present(widget.controller).scopeSummary),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final item in const [
            'Comparisons',
            'Monthly trends',
            'Follow-up lists'
          ].indexed)
            ChoiceChip(
                key: Key('explore-tab-${item.$1}'),
                label: Text(item.$2),
                selected: _tab == item.$1,
                onSelected: (_) => setState(() => _tab = item.$1)),
        ]),
        const SizedBox(height: 20),
        if (_tab == 0) _comparisons(),
        if (_tab == 1) _trends(),
        if (_tab == 2) _followUp(),
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
    final ranked = _data.ranked(_metric, ascending: _ascending);
    final shown = _compare && _data.rows.isNotEmpty
        ? [_data.rows[_a], if (_a != _b) _data.rows[_b]]
        : (_limit == null ? ranked : ranked.take(_limit!).toList());
    final maximum = shown.fold<double>(
        0, (m, r) => math.max(m, (r.value(_metric) ?? 0).abs().toDouble()));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 12, runSpacing: 12, children: [
        _select<ComparisonDimension>(
            'Compare',
            _dimension,
            ComparisonDimension.values,
            (d) => d.label,
            (d) => setState(() {
                  _dimension = d;
                  _load();
                }),
            key: 'explore-dimension'),
        _select<ComparisonMetric>('Measure', _metric, ComparisonMetric.values,
            (m) => m.label, (m) => setState(() => _metric = m),
            key: 'explore-metric'),
        _select<bool>(
            'Order',
            _ascending,
            const [false, true],
            (b) => b ? 'Lowest first' : 'Highest first',
            (b) => setState(() => _ascending = b),
            key: 'explore-order'),
        _select<int>(
            'Show',
            _limit ?? 0,
            const [5, 10, 0],
            (i) => i == 0 ? 'All results' : '$i results',
            (i) => setState(() => _limit = i == 0 ? null : i),
            key: 'explore-limit'),
      ]),
      const SizedBox(height: 12),
      Text(_metric.definition),
      const SizedBox(height: 12),
      Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChip(
                label: const Text('Compare two'),
                selected: _compare,
                onSelected: _data.rows.length < 2
                    ? null
                    : (b) => setState(() => _compare = b)),
            Text(
                '${_data.rows.length} groups · current-view ${_metric.label.toLowerCase()}: ${_metric.format(_data.total.value(_metric))}'),
          ]),
      if (_compare && _data.rows.length >= 2) ...[
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _select<int>('A', _a, List.generate(_data.rows.length, (i) => i),
              (i) => _data.rows[i].label, (i) => setState(() => _a = i),
              key: 'compare-a'),
          _select<int>('B', _b, List.generate(_data.rows.length, (i) => i),
              (i) => _data.rows[i].label, (i) => setState(() => _b = i),
              key: 'compare-b'),
        ]),
      ],
      const SizedBox(height: 16),
      if (shown.isEmpty) const Text('No groups match the current filters.'),
      Card(
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (final row in shown)
              _ComparisonBar(
                  label: row.label,
                  value: _metric.format(row.value(_metric)),
                  contextLabel: sampleLabel(row, _metric),
                  fraction: maximum == 0
                      ? 0
                      : (row.value(_metric) ?? 0).abs() / maximum,
                  onTap: row.evidence(_metric).isEmpty
                      ? null
                      : () => _evidence(row, _metric)),
          ])),
      if (_compare && shown.length == 2) ...[
        const SizedBox(height: 12),
        const Text(
            'Both groups use the same filters and period. Select another measure to compare volume, value, conversion and pipeline health. Higher is not always better—for example, delivery duration and stale value.'),
      ],
    ]);
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
          'Active and stale values are available in Comparisons. Historical pipeline trends are not reconstructed from this extract.'),
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
      {required this.label,
      required this.value,
      required this.contextLabel,
      required this.fraction,
      required this.onTap});
  final String label, value, contextLabel;
  final double fraction;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleMedium),
                  Text(value, style: Theme.of(context).textTheme.titleMedium),
                ]),
            const SizedBox(height: 8),
            ExcludeSemantics(
                child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 6,
                    color: AppColors.info,
                    backgroundColor: AppColors.canvas)),
            const SizedBox(height: 6),
            Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(contextLabel),
                  if (onTap != null)
                    const Text('View records →',
                        style: TextStyle(color: AppColors.info)),
                ]),
          ])));
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
                                                    ? Colors.white
                                                    : AppColors.info,
                                                border: Border.all(
                                                    color: AppColors.info,
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
      {required this.points,
      required this.qualified,
      required this.baseline,
      required this.left,
      required this.right});
  final List<Offset?> points;
  final List<bool> qualified;
  final double baseline, left, right;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(Offset(left, 20), Offset(left, baseline),
        Paint()..color = AppColors.border);
    canvas.drawLine(Offset(left, baseline), Offset(right, baseline),
        Paint()..color = AppColors.border);
    final paint = Paint()
      ..color = AppColors.info
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
      oldDelegate.points != points || oldDelegate.right != right;
}
