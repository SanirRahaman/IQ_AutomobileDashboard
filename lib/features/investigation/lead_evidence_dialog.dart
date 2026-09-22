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
}) {
  final records = {
    for (final lead in controller.results.leadScope.leads) lead.id: lead,
    for (final lead in controller.results.deliveryScope.leads) lead.id: lead,
  };
  final branchName = controller.dataset.branches
      .where((b) => b.id == controller.filters.branchId)
      .map((b) => b.name)
      .firstOrNull;
  const exporter = FollowUpCsv();
  final exportLabel = '${branchName ?? 'all-branches'}-$title';
  final activeCsv = exporter.create(
      dataset: controller.dataset,
      scopedRecords: records.values,
      requestedIds: leadIds,
      label: exportLabel,
      reason: inclusionReason ?? footer,
      reasons: inclusionReasons);
  final allCsv = exporter.create(
      dataset: controller.dataset,
      scopedRecords: records.values,
      requestedIds: leadIds,
      label: exportLabel,
      activeOnly: false,
      reason: inclusionReason ?? footer,
      reasons: inclusionReasons);
  void save(BuildContext context, CsvExport csv) {
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

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(subtitle,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close evidence',
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  if (activeCsv.count > 0)
                    FilledButton.icon(
                        key: const Key('export-follow-up'),
                        onPressed: () => save(dialogContext, activeCsv),
                        icon: const Icon(Icons.download, size: 18),
                        label: Text('Download follow-up (${activeCsv.count})')),
                  OutlinedButton.icon(
                      key: const Key('export-records'),
                      onPressed: allCsv.count == 0
                          ? null
                          : () => save(dialogContext, allCsv),
                      icon: const Icon(Icons.download, size: 18),
                      label: Text('All ${allCsv.count} records · CSV')),
                ])),
            const Divider(height: 1),
            Expanded(
              child: leadIds.isEmpty
                  ? const Center(
                      child: Text('No supporting opportunities are available.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: leadIds.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final id = leadIds[index];
                        final record = records[id];
                        return ListTile(
                          key: Key('evidence-lead-$id'),
                          dense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          title: Text(record?.lead.customerName ?? id),
                          subtitle: Text(record == null
                              ? 'Record $id'
                              : '$id · ${record.lead.modelInterested} · '
                                  '${_humanize(record.lead.status.rawValue)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(record == null
                                  ? '—'
                                  : DashboardPresenter.formatValue(
                                      record.dealValue)),
                              const SizedBox(width: 6),
                              const Icon(Icons.chevron_right,
                                  color: AppColors.muted),
                            ],
                          ),
                          onTap: record == null
                              ? null
                              : () => showLeadEvidenceDialog(
                                    context: context,
                                    controller: controller,
                                    record: record,
                                    inclusionReason:
                                        inclusionReasons[id] ?? inclusionReason,
                                  ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColors.canvas,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Text(
                  '$footer\nFollow-up downloads contain active opportunities only.',
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showLeadEvidenceDialog({
  required BuildContext context,
  required AnalysisController controller,
  required AnalyticalLead record,
  String? inclusionReason,
}) {
  final branch = controller.dataset.branches
      .where((item) => item.id == record.branchId)
      .firstOrNull;
  final rep = controller.dataset.salesReps
      .where((item) => item.id == record.repId)
      .firstOrNull;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(18),
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 820),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 22, 16, 18),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(record.lead.customerName,
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 4),
                        Text('Lead ${record.id}',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close lead evidence',
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (inclusionReason != null) ...[
                      Container(
                        key: const Key('lead-inclusion-reason'),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.infoSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFB2DDFF)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline,
                                color: AppColors.info, size: 19),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text('Included because $inclusionReason',
                                  style:
                                      Theme.of(context).textTheme.bodyMedium),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Text('Lead details',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    _DetailGrid(items: [
                      ('Phone', record.lead.phone),
                      (
                        'Data as of',
                        DashboardPresenter.formatDate(
                            record.context.snapshotDate)
                      ),
                      ('Vehicle', record.lead.modelInterested),
                      (
                        'Source',
                        _humanize(record.lead.source ?? 'Unattributed')
                      ),
                      (
                        'Deal value',
                        DashboardPresenter.formatValue(record.dealValue)
                      ),
                      (
                        'Current status',
                        _humanize(record.lead.status.rawValue)
                      ),
                      (
                        'Expected close',
                        _timestamp(record.lead.expectedCloseDate,
                            dateOnly: true)
                      ),
                      ('Last activity', _timestamp(record.lead.lastActivityAt)),
                    ]),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: branch == null
                              ? null
                              : () {
                                  final navigator = Navigator.of(dialogContext);
                                  navigator.popUntil(
                                      (route) => route is! PopupRoute<void>);
                                  AppNavigation.go(context,
                                      '/branch/${Uri.encodeComponent(branch.id)}',
                                      filters: controller.filters);
                                },
                          icon: const Icon(Icons.store_outlined, size: 17),
                          label: Text(branch?.name ?? record.branchId),
                        ),
                        OutlinedButton.icon(
                          onPressed: rep == null
                              ? null
                              : () {
                                  final navigator = Navigator.of(dialogContext);
                                  navigator.popUntil(
                                      (route) => route is! PopupRoute<void>);
                                  AppNavigation.go(context,
                                      '/rep/${Uri.encodeComponent(rep.id)}',
                                      filters: controller.filters);
                                },
                          icon: const Icon(Icons.person_outline, size: 17),
                          label: Text(rep?.name ?? record.repId),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text('Complete status timeline',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 14),
                    ...record.lead.statusHistory.indexed
                        .map((item) => _TimelineEntry(
                              entry: item.$2,
                              isLast: item.$1 ==
                                  record.lead.statusHistory.length - 1,
                            )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

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
