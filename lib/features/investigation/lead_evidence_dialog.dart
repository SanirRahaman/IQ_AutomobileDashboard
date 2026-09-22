import '../../app/analysis_router.dart';
import '../../application/export/follow_up_csv.dart';
import '../../platform/download.dart';
import 'package:flutter/material.dart';

import '../../analytics/models/analytical_lead.dart';
import '../../application/analysis/analysis_controller.dart';
import '../../app/app_theme.dart';
import '../../data/models/dealership_models.dart';
import '../dashboard/dashboard_view_data.dart';

Future<void> showEvidenceListDialog({
  required BuildContext context,
  required AnalysisController controller,
  required String title,
  required String subtitle,
  required List<String> leadIds,
  required String footer,
  String? inclusionReason,
  Map<String, String> inclusionReasons = const {},
  Map<String, List<String>> groups = const {},
  List<Delivery>? deliveries,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _EvidenceListDialog(
      controller: controller,
      title: title,
      subtitle: subtitle,
      leadIds: leadIds,
      footer: footer,
      inclusionReason: inclusionReason,
      inclusionReasons: inclusionReasons,
      groups: groups,
      deliveries: deliveries,
    ),
  );
}

class _EvidenceListDialog extends StatefulWidget {
  const _EvidenceListDialog({
    required this.controller,
    required this.title,
    required this.subtitle,
    required this.leadIds,
    required this.footer,
    required this.inclusionReason,
    required this.inclusionReasons,
    required this.groups,
    required this.deliveries,
  });

  final AnalysisController controller;
  final String title;
  final String subtitle;
  final List<String> leadIds;
  final String footer;
  final String? inclusionReason;
  final Map<String, String> inclusionReasons;
  final Map<String, List<String>> groups;
  final List<Delivery>? deliveries;

  @override
  State<_EvidenceListDialog> createState() => _EvidenceListDialogState();
}

class _EvidenceListDialogState extends State<_EvidenceListDialog> {
  int? _selectedIndex;
  int _groupIndex = 0;

  Map<String, AnalyticalLead> get _records => {
        for (final lead in widget.controller.results.leadScope.leads)
          lead.id: lead,
        for (final lead in widget.controller.results.deliveryScope.leads)
          lead.id: lead,
      };

  void _save(CsvExport csv) {
    try {
      downloadCsv(csv.filename, csv.content);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download requested: ${csv.count} records')));
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Download could not start. Please try again in a web browser.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = _records;
    final ids = widget.groups.isEmpty
        ? widget.leadIds
        : widget.groups.values.elementAt(_groupIndex);
    final selectedId = _selectedIndex == null ? null : ids[_selectedIndex!];
    final selectedDelivery =
        _selectedIndex == null ? null : widget.deliveries?[_selectedIndex!];
    final branchName = widget.controller.dataset.branches
        .where((b) => b.id == widget.controller.filters.branchId)
        .map((b) => b.name)
        .firstOrNull;
    const exporter = FollowUpCsv();
    final exportLabel = '${branchName ?? 'all-branches'}-${widget.title}';
    final activeCsv = exporter.create(
        dataset: widget.controller.dataset,
        scopedRecords: records.values,
        requestedIds: ids,
        label: exportLabel,
        reason: widget.inclusionReason ?? widget.footer,
        reasons: widget.inclusionReasons);
    final allCsv = widget.deliveries != null
        ? exporter.createDeliveries(
            dataset: widget.controller.dataset,
            deliveries: widget.deliveries!,
            label: exportLabel)
        : exporter.create(
            dataset: widget.controller.dataset,
            scopedRecords: records.values,
            requestedIds: ids,
            label: exportLabel,
            activeOnly: false,
            reason: widget.inclusionReason ?? widget.footer,
            reasons: widget.inclusionReasons);
    final selected = records[selectedId];
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1120,
          maxHeight: MediaQuery.sizeOf(context).height - 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .24),
                child: SingleChildScrollView(
                    child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 16, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.title,
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 4),
                            Text(widget.subtitle,
                                style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close evidence',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ))),
            Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  if (activeCsv.count > 0 && widget.deliveries == null)
                    FilledButton.icon(
                        key: const Key('export-follow-up'),
                        onPressed: () => _save(activeCsv),
                        icon: const Icon(Icons.download, size: 18),
                        label: Text('Download follow-up (${activeCsv.count})')),
                  OutlinedButton.icon(
                      key: const Key('export-records'),
                      onPressed: allCsv.count == 0 ? null : () => _save(allCsv),
                      icon: const Icon(Icons.download, size: 18),
                      label: Text('All ${allCsv.count} records · CSV')),
                ])),
            if (widget.groups.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Wrap(spacing: 8, runSpacing: 4, children: [
                  for (final item in widget.groups.entries.indexed)
                    ChoiceChip(
                      label: Text('${item.$2.key} (${item.$2.value.length})'),
                      selected: _groupIndex == item.$1,
                      onSelected: (_) => setState(() {
                        _groupIndex = item.$1;
                        _selectedIndex = null;
                      }),
                    ),
                ]),
              ),
            const Divider(height: 1),
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                final split = constraints.maxWidth >= 760;
                final list = _EvidenceRecordList(
                  leadIds: ids,
                  records: records,
                  deliveries: widget.deliveries,
                  selectedIndex: _selectedIndex,
                  onSelected: (index) => setState(() => _selectedIndex = index),
                );
                final detail = AnimatedSwitcher(
                  layoutBuilder: (current, previous) => Stack(
                    fit: StackFit.expand,
                    children: [...previous, if (current != null) current],
                  ),
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: selected == null
                      ? const KeyedSubtree(
                          key: ValueKey('evidence-placeholder'),
                          child: _EvidencePlaceholder(),
                        )
                      : KeyedSubtree(
                          key: ValueKey('$_groupIndex-$_selectedIndex'),
                          child: _LeadEvidencePanel(
                            controller: widget.controller,
                            record: selected,
                            inclusionReason:
                                widget.inclusionReasons[selected.id] ??
                                    widget.inclusionReason,
                            delivery: selectedDelivery,
                            onClose: () =>
                                setState(() => _selectedIndex = null),
                          ),
                        ),
                );
                return split
                    ? Row(children: [
                        SizedBox(width: 430, child: list),
                        const VerticalDivider(width: 1),
                        Expanded(child: detail),
                      ])
                    : Column(children: [
                        if (selected == null) Expanded(child: list),
                        if (selected != null) ...[
                          SizedBox(
                              height: constraints.maxHeight * .28, child: list),
                          const Divider(height: 1),
                          Expanded(child: detail),
                        ],
                      ]);
              }),
            ),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColors.canvas,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * .12),
                  child: SingleChildScrollView(
                      child: Text(
                          activeCsv.count > 0
                              ? '${widget.footer}\nFollow-up downloads contain active opportunities only.'
                              : widget.footer,
                          style: Theme.of(context).textTheme.bodyMedium))),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvidenceRecordList extends StatelessWidget {
  const _EvidenceRecordList({
    required this.leadIds,
    required this.records,
    required this.selectedIndex,
    required this.onSelected,
    this.deliveries,
  });

  final List<String> leadIds;
  final Map<String, AnalyticalLead> records;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;
  final List<Delivery>? deliveries;

  @override
  Widget build(BuildContext context) {
    if (leadIds.isEmpty) {
      return const Center(
          child: Text('No supporting opportunities are available.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: leadIds.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final id = leadIds[index];
        final record = records[id];
        final selected = index == selectedIndex;
        final delivery = deliveries?[index];
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: selected ? AppColors.infoSoft : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: selected ? AppColors.info : AppColors.border),
          ),
          child: ListTile(
            key: Key(delivery == null
                ? 'evidence-lead-$id'
                : 'evidence-delivery-$index'),
            selected: selected,
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            title: Text(record?.lead.customerName ?? id),
            subtitle: Text(delivery != null
                ? '${DashboardPresenter.formatDate(delivery.deliveryDate)} · ${record?.vehicleModel ?? id}'
                : record == null
                    ? 'Record $id'
                    : '$id · ${record.lead.modelInterested} · '
                        '${_humanize(record.lead.status.rawValue)}'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(record == null
                  ? '—'
                  : DashboardPresenter.formatValue(record.dealValue)),
              const SizedBox(width: 6),
              Icon(selected ? Icons.arrow_forward : Icons.chevron_right,
                  color: selected ? AppColors.info : AppColors.muted),
            ]),
            onTap: record == null ? null : () => onSelected(index),
          ),
        );
      },
    );
  }
}

class _EvidencePlaceholder extends StatelessWidget {
  const _EvidencePlaceholder();

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.touch_app_outlined,
                size: 34, color: AppColors.muted),
            const SizedBox(height: 12),
            Text('Select a supporting record',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('The selected record and its evidence will appear here.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
          ]),
        ),
      );
}

Future<void> showLeadEvidenceDialog({
  required BuildContext context,
  required AnalysisController controller,
  required AnalyticalLead record,
  String? inclusionReason,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 820),
        child: _LeadEvidencePanel(
          controller: controller,
          record: record,
          inclusionReason: inclusionReason,
        ),
      ),
    ),
  );
}

class _LeadEvidencePanel extends StatelessWidget {
  const _LeadEvidencePanel({
    required this.controller,
    required this.record,
    required this.inclusionReason,
    this.onClose,
    this.delivery,
  });

  final AnalysisController controller;
  final AnalyticalLead record;
  final String? inclusionReason;
  final VoidCallback? onClose;
  final Delivery? delivery;

  @override
  Widget build(BuildContext context) {
    final branch = controller.dataset.branches
        .where((item) => item.id == record.branchId)
        .firstOrNull;
    final rep = controller.dataset.salesReps
        .where((item) => item.id == record.repId)
        .firstOrNull;
    void navigateTo(String path) {
      Navigator.of(context).pop();
      AppNavigation.go(context, path, filters: controller.filters);
    }

    return SingleChildScrollView(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.lead.customerName,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 3),
                    Text('Lead ${record.id} · Selected supporting record',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ]),
            ),
            IconButton(
              tooltip: onClose == null
                  ? 'Close lead evidence'
                  : 'Clear selected record',
              onPressed: onClose ?? () => Navigator.maybePop(context),
              icon: const Icon(Icons.close),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (delivery != null) ...[
              Text('Delivery record',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              _DetailGrid(items: [
                (
                  'Delivery date',
                  DashboardPresenter.formatDate(delivery!.deliveryDate)
                ),
                (
                  'Order date',
                  DashboardPresenter.formatDate(delivery!.orderDate)
                ),
                ('Recorded duration', '${delivery!.daysToDeliver} days'),
                (
                  'Recorded delay reason',
                  delivery!.delayReason ?? 'None recorded'
                ),
              ]),
              const SizedBox(height: 16),
            ],
            if (inclusionReason != null) ...[
              Container(
                key: const Key('lead-inclusion-reason'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.infoSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFB2DDFF)),
                ),
                child: Text('Included because $inclusionReason',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              const SizedBox(height: 16),
            ],
            Text('Lead details',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            _DetailGrid(items: [
              ('Phone', record.lead.phone),
              (
                'Data as of',
                DashboardPresenter.formatDate(record.context.snapshotDate)
              ),
              ('Vehicle', record.lead.modelInterested),
              ('Source', _humanize(record.lead.source ?? 'Unattributed')),
              ('Deal value', DashboardPresenter.formatValue(record.dealValue)),
              ('Current status', _humanize(record.lead.status.rawValue)),
              (
                'Expected close',
                _timestamp(record.lead.expectedCloseDate, dateOnly: true)
              ),
              ('Last activity', _timestamp(record.lead.lastActivityAt)),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                onPressed: branch == null
                    ? null
                    : () =>
                        navigateTo('/branch/${Uri.encodeComponent(branch.id)}'),
                icon: const Icon(Icons.store_outlined, size: 17),
                label: Text(branch?.name ?? record.branchId),
              ),
              OutlinedButton.icon(
                onPressed: rep == null
                    ? null
                    : () => navigateTo('/rep/${Uri.encodeComponent(rep.id)}'),
                icon: const Icon(Icons.person_outline, size: 17),
                label: Text(rep?.name ?? record.repId),
              ),
            ]),
            const SizedBox(height: 22),
            Text('Complete status timeline',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...record.lead.statusHistory.indexed.map((item) => _TimelineEntry(
                  entry: item.$2,
                  isLast: item.$1 == record.lead.statusHistory.length - 1,
                )),
          ]),
        ),
      ],
    ));
  }
}

// The list and detail views intentionally share one dialog so the selected record remains in context.

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.items});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth >= 420
          ? (constraints.maxWidth - 10) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items
            .map((item) => Container(
                  width: width,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.canvas,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.$1,
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 3),
                      Text(item.$2,
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                ))
            .toList(),
      );
    });
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({required this.entry, required this.isLast});

  final LeadStatusHistoryEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.ink,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 1, color: AppColors.border),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_humanize(entry.status.rawValue),
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(_timestamp(entry.timestamp),
                      style: Theme.of(context).textTheme.bodyMedium),
                  if (entry.note != null && entry.note!.trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(entry.note!,
                        style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _humanize(String value) => value
    .split('_')
    .map((word) => word.isEmpty
        ? word
        : '${word.substring(0, 1).toUpperCase()}${word.substring(1)}')
    .join(' ');

String _timestamp(DateTime value, {bool dateOnly = false}) {
  final utc = value.toUtc();
  final date = '${utc.day.toString().padLeft(2, '0')} '
      '${const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ][utc.month - 1]} '
      '${utc.year}';
  if (dateOnly) return date;
  return '$date · ${utc.hour.toString().padLeft(2, '0')}:'
      '${utc.minute.toString().padLeft(2, '0')} UTC';
}
