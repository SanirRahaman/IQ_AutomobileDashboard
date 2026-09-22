import 'package:flutter/material.dart';
import '../../analytics/services/management_performance.dart';
import '../../application/analysis/analysis_controller.dart';
import '../../app/analysis_router.dart';
import '../../app/app_theme.dart';
import '../dashboard/dashboard_view_data.dart';

class TargetPanel extends StatelessWidget {
  const TargetPanel({super.key, required this.controller});
  final AnalysisController controller;
  @override
  Widget build(BuildContext context) {
    final performance = controller.results.performance;
    final total = performance.total;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text('Deliveries vs target',
                            style: Theme.of(context).textTheme.titleLarge)),
                    Tooltip(
                        message:
                            'Actuals use delivery dates, matched to supplied branch-month unit targets. Missing or duplicate targets are excluded from both sides. Targets are not assigned to representatives or prorated. The extract may not cover all business behind the supplied targets.',
                        child: IconButton(
                            tooltip: 'How targets are compared',
                            onPressed: () => showDialog<void>(
                                context: context,
                                builder: (c) => AlertDialog(
                                        title: const Text('About the targets'),
                                        content: const Text(
                                            'Targets are supplied for each branch and month. Actuals count linked delivery records in the selected period. Missing or duplicate targets are excluded from both sides. Partial months retain the full monthly target. No representative, source, model or status targets are supplied.\n\nThe source does not establish whether these targets cover the same business population as the extract. Confirm coverage before using the gap to judge performance.'),
                                        actions: [
                                          TextButton(
                                              onPressed: () => Navigator.pop(c),
                                              child: const Text('Close'))
                                        ])),
                            icon: const Icon(Icons.info_outline, size: 18)))
                  ]),
                  if (performance.unavailableReason != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(performance.unavailableReason!)),
                  if (total != null) ...[
                    Text(
                        '${total.actual} actual / ${total.target} target · ${DashboardPresenter.formatRate(total.attainment)} attained',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(total.status),
                    if (total.missingMonths > 0)
                      Text(
                          '${total.missingMonths} branch-month targets missing or ambiguous; excluded.',
                          style: const TextStyle(color: AppColors.warning)),
                    const SizedBox(height: 8),
                    ...performance.branches.map((row) => _TargetRow(
                        row: row,
                        onPressed: () => AppNavigation.go(context,
                            '/branch/${Uri.encodeComponent(row.branchId!)}',
                            filters: controller.filters))),
                    const SizedBox(height: 8),
                    const Text(
                        'Supplied targets · confirm that the extract covers the same business.',
                        style: TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                  if (performance.comparison != null) ...[
                    const Divider(height: 22),
                    Text(
                        '${performance.comparison!.current} deliveries vs ${performance.comparison!.previous} in ${DashboardPresenter.formatMonth(performance.comparison!.previousStart)}',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                        '${performance.comparison!.difference >= 0 ? '+' : ''}${performance.comparison!.difference} vehicles · complete calendar months, by delivery date'),
                  ],
                ])));
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({required this.row, required this.onPressed});
  final TargetPerformance row;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onPressed,
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(row.branchName,
                      style: Theme.of(context).textTheme.titleMedium)),
              const Icon(Icons.chevron_right, size: 18)
            ]),
            const SizedBox(height: 4),
            if (row.target != null) ...[
              Semantics(
                  label:
                      '${row.branchName}: ${row.actual} actual, ${row.target} target, ${row.status}',
                  child: LinearProgressIndicator(
                      value: row.progress,
                      minHeight: 5,
                      backgroundColor: AppColors.border,
                      color: AppColors.info)),
              const SizedBox(height: 4),
              Text(
                  '${row.actual} / ${row.target} · ${DashboardPresenter.formatRate(row.attainment)} · ${row.status}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ] else
              const Text('No comparable target'),
          ])));
}
