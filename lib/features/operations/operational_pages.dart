import '../dashboard/dashboard_view_data.dart';
import '../../app/analysis_router.dart';
import 'package:flutter/material.dart';

import '../../application/analysis/analysis_controller.dart';
import '../../application/analysis/analysis_filters.dart';
import '../../app/app_theme.dart';
import '../investigation/lead_evidence_dialog.dart';
import 'operational_view_data.dart';

class PipelinePage extends StatefulWidget {
  const PipelinePage({super.key, required this.controller});
  final AnalysisController controller;

  @override
  State<PipelinePage> createState() => _PipelinePageState();
}

class _PipelinePageState extends State<PipelinePage> {
  static const _presenter = OperationalPresenter();
  late PipelineViewData _data;

  @override
  void initState() {
    super.initState();
    _data = _presenter.pipeline(widget.controller);
    widget.controller.addListener(_refresh);
  }

  void _refresh() =>
      setState(() => _data = _presenter.pipeline(widget.controller));

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _OperationsScaffold(
        controller: widget.controller,
        title: 'Active opportunities',
        question:
            'Which opportunities are truly active, and which require verification or intervention?',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _KpiGrid(items: [
              ('Active leads', _data.activeCount),
              ('Active opportunity value', _data.activeValue),
              ('Stale opportunity value', _data.staleValue),
              ('Order-stage backlog', _data.backlog.primary),
            ]),
            const SizedBox(height: 16),
            _DefinitionBanner(text: _data.thresholdDescription),
            const SizedBox(height: 28),
            _Pair(
              first: _Panel(
                title: 'Pipeline by stage',
                child: _EvidenceRows(
                  rows: _data.byStage,
                  controller: widget.controller,
                  reason: (row) =>
                      'this active opportunity is currently in ${row.label.toLowerCase()}',
                ),
              ),
              second: _Panel(
                title: 'Inactivity distribution',
                child: _EvidenceRows(
                  rows: _data.inactivity,
                  controller: widget.controller,
                  reason: (row) =>
                      'its inactivity falls in the ${row.label.toLowerCase()} attention band',
                ),
              ),
            ),
            _Pair(
              first: _Panel(
                title: 'Opportunity age distribution',
                child: _EvidenceRows(
                  rows: _data.age,
                  controller: widget.controller,
                  reason: (row) =>
                      'its age falls in the ${row.label.toLowerCase()} band',
                ),
              ),
              second: _Panel(
                title: 'Expected-close and order backlog',
                child: _EvidenceRows(
                  rows: [_data.slippage, _data.backlog],
                  controller: widget.controller,
                  reason: (row) => row.label == 'Expected close overdue'
                      ? 'its expected-close date is before the data snapshot'
                      : 'it remains active at the order-placed stage',
                ),
              ),
            ),
            _Panel(
              title: 'Oldest active opportunities',
              description:
                  'Age and inactivity are verification signals. They do not reclassify an active record as lost.',
              child: _EvidenceRows(
                rows: _data.oldest,
                controller: widget.controller,
                reason: (row) =>
                    'it is among the oldest active opportunities in the current view',
              ),
            ),
            _Pair(
              first: _Panel(
                title: 'Branch breakdown',
                child: _EvidenceRows(
                  rows: _data.branches,
                  controller: widget.controller,
                  reason: (row) =>
                      'it is an active opportunity assigned to ${row.label}',
                ),
              ),
              second: _Panel(
                title: 'Representative breakdown',
                child: _EvidenceRows(
                  rows: _data.reps,
                  controller: widget.controller,
                  reason: (row) =>
                      'it is an active opportunity assigned to ${row.label}',
                ),
              ),
            ),
          ],
        ),
      );
}

class DeliveryPage extends StatefulWidget {
  const DeliveryPage({super.key, required this.controller});
  final AnalysisController controller;

  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  static const _presenter = OperationalPresenter();
  late DeliveryViewData _data;

  @override
  void initState() {
    super.initState();
    _data = _presenter.delivery(widget.controller);
    widget.controller.addListener(_refresh);
  }

  void _refresh() =>
      setState(() => _data = _presenter.delivery(widget.controller));

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _OperationsScaffold(
        controller: widget.controller,
        title: 'Delivery performance',
        question:
            'Are completed sales being fulfilled efficiently and reliably?',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _KpiGrid(items: [
              ('Deliveries', _data.count),
              ('Median delivery duration', _data.median),
              ('Average delivery duration', _data.average),
            ]),
            const SizedBox(height: 28),
            _Panel(
              title: 'Delivery-duration distribution',
              child: _EvidenceRows(
                rows: _data.distribution,
                controller: widget.controller,
                reason: (_) =>
                    'it is a linked delivery in the selected delivery period',
              ),
            ),
            _Pair(
              first: _Panel(
                title: 'Branch comparison',
                child: _EvidenceRows(
                  rows: _data.branches,
                  controller: widget.controller,
                  reason: (row) => 'its delivery belongs to ${row.label}',
                ),
              ),
              second: _Panel(
                title: 'Vehicle comparison',
                child: _EvidenceRows(
                  rows: _data.vehicles,
                  controller: widget.controller,
                  reason: (row) => 'the delivered vehicle is ${row.label}',
                ),
              ),
            ),
            _Panel(
              title: 'Recorded delay reasons',
              description:
                  'Incremental time is an observed association against deliveries without a recorded delay. It does not establish causality.',
              child: _EvidenceRows(
                rows: _data.delayReasons,
                controller: widget.controller,
                reason: (row) =>
                    'the linked delivery records “${row.label}” as its delay reason',
              ),
            ),
            _Panel(
              title: 'Expected-close timeliness',
              description:
                  'Shown only where the delivery can be linked to a lead expected-close date.',
              child: _EvidenceRows(
                rows: _data.expectedClose,
                controller: widget.controller,
                reason: (row) => row.label.toLowerCase(),
              ),
            ),
          ],
        ),
      );
}

class _OperationsScaffold extends StatelessWidget {
  const _OperationsScaffold({
    required this.controller,
    required this.title,
    required this.question,
    required this.body,
  });
  final AnalysisController controller;
  final String title;
  final String question;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final horizontal = MediaQuery.sizeOf(context).width >= 720 ? 32.0 : 16.0;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        title: const Text('yoyotaDealers'),
        actions: [
          TextButton(
            onPressed: () => AppNavigation.go(context, '/'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Overview'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          _OperationalFilterBar(controller: controller),
          Expanded(
            child: SelectionArea(
              child: SingleChildScrollView(
                key: const Key('operations-scroll'),
                padding: EdgeInsets.fromLTRB(horizontal, 28, horizontal, 52),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1360),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                            'Data as of ${DashboardPresenter.formatDate(controller.results.performance.snapshot)} · Ages and overdue alerts use this date',
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(
                            '${DashboardPresenter.formatDate(controller.results.performance.start)} – ${DashboardPresenter.formatDate(controller.results.performance.end)}'),
                        const SizedBox(height: 8),
                        Text(title,
                            style: Theme.of(context).textTheme.displaySmall),
                        const SizedBox(height: 7),
                        Text(question,
                            style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: 26),
                        body,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationalFilterBar extends StatelessWidget {
  const _OperationalFilterBar({required this.controller});
  final AnalysisController controller;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(children: [
          const Icon(Icons.filter_alt_outlined, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(controller.filters.isDefault
                ? 'Network · all available dates'
                : 'Selected filters applied'),
          ),
          OutlinedButton.icon(
            key: const Key('operations-filters'),
            onPressed: () async {
              final filters = await showDialog<AnalysisFilters>(
                context: context,
                builder: (_) => _FiltersDialog(controller: controller),
              );
              if (filters != null) controller.replaceFilters(filters);
            },
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('Filters'),
          ),
          if (!controller.filters.isDefault) ...[
            const SizedBox(width: 6),
            TextButton(onPressed: controller.reset, child: const Text('Reset')),
          ],
        ]),
      );
}

class _FiltersDialog extends StatefulWidget {
  const _FiltersDialog({required this.controller});
  final AnalysisController controller;

  @override
  State<_FiltersDialog> createState() => _FiltersDialogState();
}

class _FiltersDialogState extends State<_FiltersDialog> {
  late AnalysisDateRange? _dates = widget.controller.filters.dateRange;
  late String? _branch = widget.controller.filters.branchId;
  late String? _rep = widget.controller.filters.repId;
  late String? _source = widget.controller.filters.source;
  late String? _model = widget.controller.filters.vehicleModel;
  late String? _status = widget.controller.filters.leadStatus;

  @override
  Widget build(BuildContext context) {
    final dataset = widget.controller.dataset;
    final reps = dataset.salesReps
        .where((item) => _branch == null || item.branchId == _branch)
        .toList();
    return AlertDialog(
      title: const Text('Filter opportunities'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date range'),
              subtitle: Text(_dates == null
                  ? 'All available dates'
                  : '${_date(_dates!.start)} – ${_date(_dates!.end)}'),
              trailing: IconButton(
                icon: const Icon(Icons.date_range),
                onPressed: () async {
                  final values = [
                    ...dataset.leads.map((item) => item.createdAt),
                    ...dataset.deliveries.map((item) => item.deliveryDate),
                  ]..sort();
                  if (values.isEmpty) return;
                  final selected = await showDateRangePicker(
                    context: context,
                    firstDate: values.first,
                    lastDate: values.last,
                    initialDateRange: _dates == null ||
                            _dates!.start.isBefore(values.first) ||
                            _dates!.end.isAfter(values.last)
                        ? null
                        : DateTimeRange(start: _dates!.start, end: _dates!.end),
                  );
                  if (selected != null) {
                    setState(() => _dates = AnalysisDateRange(
                        start: selected.start, end: selected.end));
                  }
                },
              ),
            ),
            _dropdown(
                'Branch',
                _branch,
                'All branches',
                dataset.branches.map((item) => MapEntry(item.id, item.name)),
                (value) => setState(() {
                      _branch = value;
                      if (!dataset.salesReps.any((item) =>
                          item.id == _rep &&
                          (value == null || item.branchId == value))) {
                        _rep = null;
                      }
                    })),
            _dropdown(
                'Sales representative',
                _rep,
                'All representatives',
                reps.map((item) => MapEntry(item.id, item.name)),
                (value) => setState(() => _rep = value)),
            _dropdown(
                'Lead source',
                _source,
                'All sources',
                dataset.leads
                    .map((item) => item.source)
                    .whereType<String>()
                    .toSet()
                    .map((item) => MapEntry(item, item.replaceAll('_', ' '))),
                (value) => setState(() => _source = value)),
            _dropdown(
                'Vehicle model',
                _model,
                'All models',
                dataset.leads
                    .map((item) => item.modelInterested)
                    .toSet()
                    .map((item) => MapEntry(item, item)),
                (value) => setState(() => _model = value)),
            _dropdown(
                'Lead status',
                _status,
                'All statuses',
                dataset.leads
                    .map((item) => item.status.rawValue)
                    .toSet()
                    .map((item) => MapEntry(item, item.replaceAll('_', ' '))),
                (value) => setState(() => _status = value)),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => setState(() {
                  _dates = null;
                  _branch = null;
                  _rep = null;
                  _source = null;
                  _model = null;
                  _status = null;
                }),
            child: const Text('Clear')),
        FilledButton(
          onPressed: () => Navigator.pop(
              context,
              AnalysisFilters(
                dateRange: _dates,
                branchId: _branch,
                repId: _rep,
                source: _source,
                vehicleModel: _model,
                leadStatus: _status,
              )),
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _dropdown(
      String label,
      String? value,
      String allLabel,
      Iterable<MapEntry<String, String>> options,
      ValueChanged<String?> onChanged) {
    final items = options.toList();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(labelText: label),
        items: [
          DropdownMenuItem(value: null, child: Text(allLabel)),
          ...items.map((item) =>
              DropdownMenuItem(value: item.key, child: Text(item.value))),
        ],
        onChanged: onChanged,
      ),
    );
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.items});
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (_, constraints) {
        final columns = constraints.maxWidth >= 900
            ? items.length
            : constraints.maxWidth >= 560
                ? 2
                : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map((item) => SizedBox(
                    width: width,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.$1,
                                style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: 5),
                            Text(item.$2,
                                style: Theme.of(context).textTheme.titleLarge),
                          ],
                        ),
                      ),
                    ),
                  ))
              .toList(),
        );
      });
}

class _DefinitionBanner extends StatelessWidget {
  const _DefinitionBanner({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.infoSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('$text. Classification uses days since last activity.'),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.description});
  final String title;
  final String? description;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(description!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 11),
          child,
        ]),
      );
}

class _EvidenceRows extends StatelessWidget {
  const _EvidenceRows({
    required this.rows,
    required this.controller,
    required this.reason,
  });
  final List<OperationalRow> rows;
  final AnalysisController controller;
  final String Function(OperationalRow) reason;

  @override
  Widget build(BuildContext context) => Card(
        child: rows.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No records match these filters.'))
            : Column(
                children: rows
                    .map((row) => ListTile(
                          title: Text(row.label),
                          subtitle: Text('${row.primary}\n${row.secondary}'),
                          isThreeLine: true,
                          trailing: row.leadIds.isEmpty
                              ? null
                              : const Icon(Icons.chevron_right),
                          onTap: row.leadIds.isEmpty
                              ? null
                              : () => showEvidenceListDialog(
                                    context: context,
                                    controller: controller,
                                    title: row.label,
                                    subtitle:
                                        '${row.leadIds.length} supporting records',
                                    leadIds: row.leadIds,
                                    footer:
                                        'Review the opportunities behind this measure.',
                                    inclusionReason: reason(row),
                                  ),
                        ))
                    .toList(),
              ),
      );
}

class _Pair extends StatelessWidget {
  const _Pair({required this.first, required this.second});
  final Widget first;
  final Widget second;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, constraints) => constraints.maxWidth < 900
            ? Column(children: [first, second])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: first),
                const SizedBox(width: 16),
                Expanded(child: second),
              ]),
      );
}
