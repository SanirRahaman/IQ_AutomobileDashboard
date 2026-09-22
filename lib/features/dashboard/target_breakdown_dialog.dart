import 'package:flutter/material.dart';

import '../../analytics/services/management_performance.dart';
import '../../app/app_theme.dart';
import 'dashboard_view_data.dart';

Future<void> showTargetBreakdownDialog({
  required BuildContext context,
  required ManagementPerformance performance,
}) =>
    showDialog<void>(
        context: context,
        builder: (context) {
          final total = performance.total;
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: SizedBox(
              width: 760,
              height: 680,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
                      child: Row(children: [
                        Expanded(
                            child: Text('Target attainment breakdown',
                                style: Theme.of(context).textTheme.titleLarge)),
                        IconButton(
                            tooltip: 'Close target breakdown',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close)),
                      ]),
                    ),
                    const Divider(height: 1),
                    Expanded(
                        child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                                '${DashboardPresenter.formatDate(performance.start)} – ${DashboardPresenter.formatDate(performance.end)}'),
                            const SizedBox(height: 12),
                            if (total != null) ...[
                              Text(
                                  '${DashboardPresenter.formatRate(total.attainment)} attained',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall),
                              Text(
                                  '${total.actual} actual deliveries ÷ ${total.target} target vehicles'),
                              Text(total.status),
                              const SizedBox(height: 12),
                            ],
                            if (performance.unavailableReason != null)
                              Text(performance.unavailableReason!),
                            const Text(
                                'Targets come from the supplied branch-month unit targets. '
                                'Actuals use delivery dates. Partial months retain the full monthly target. '
                                'Excluded months contribute neither actuals nor targets to the total.'),
                            const SizedBox(height: 8),
                            const Text(
                                'Confirm that the extract covers the same business as the supplied targets.',
                                style: TextStyle(color: AppColors.muted)),
                            const SizedBox(height: 16),
                            for (final month in performance.targetMonths)
                              _MonthlyTargetRow(month: month),
                          ]),
                    )),
                  ]),
            ),
          );
        });

class _MonthlyTargetRow extends StatelessWidget {
  const _MonthlyTargetRow({required this.month});
  final MonthlyTargetPerformance month;

  @override
  Widget build(BuildContext context) {
    final row = month.performance;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
            color: AppColors.canvas, borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(
                '${row.branchName} · ${DashboardPresenter.formatMonth(month.month)}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            if (row.target == null)
              const Text('Excluded · missing, duplicate or invalid target')
            else ...[
              Wrap(spacing: 16, runSpacing: 4, children: [
                Text('Actual ${row.actual}'),
                Text('Target ${row.target}'),
                Text('Variance ${row.variance! > 0 ? '+' : ''}${row.variance}'),
                Text(
                    '${DashboardPresenter.formatRate(row.attainment)} attained'),
              ]),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                  value: row.progress,
                  color: AppColors.info,
                  backgroundColor: AppColors.border),
              const SizedBox(height: 6),
              Text(row.status),
            ],
          ]),
        ),
      ),
    );
  }
}
