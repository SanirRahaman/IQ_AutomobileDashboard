import '../dashboard/dashboard_view_data.dart';
import 'package:flutter/material.dart';

import '../../application/analysis/analysis_controller.dart';
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
  Widget build(BuildContext context) => OperationsScaffold(
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
  Widget build(BuildContext context) => OperationsScaffold(
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

class OperationsScaffold extends StatelessWidget {
  const OperationsScaffold({
    super.key,
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
      body: Column(
        children: [
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
                        const SizedBox(height: 20),
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
          color: context.colors.infoSoft,
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
