import '../../analytics/models/analytical_lead.dart';
import '../../data/models/dealership_models.dart';

class CsvExport {
  const CsvExport(
      {required this.filename, required this.content, required this.count});
  final String filename;
  final String content;
  final int count;
}

/// Export selection intersects the supplied scope. Active-only lists never
/// include resolved records, even when the finding also references losses.
class FollowUpCsv {
  const FollowUpCsv();
  CsvExport create({
    required DealershipDataset dataset,
    required Iterable<AnalyticalLead> scopedRecords,
    required Iterable<String> requestedIds,
    required String label,
    bool activeOnly = true,
    String reason = '',
    Map<String, String> reasons = const {},
  }) {
    final ids = requestedIds.toSet();
    final records = {
      for (final r in scopedRecords)
        if (ids.contains(r.id) && (!activeOnly || r.isActive)) r.id: r
    }.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final branches = {for (final b in dataset.branches) b.id: b.name};
    final reps = {for (final r in dataset.salesReps) r.id: r.name};
    final rows = <List<Object?>>[
      [
        'Lead reference',
        'Customer',
        'Phone',
        'Branch',
        'Representative',
        'Vehicle',
        'Source',
        'Status',
        'Deal value (currency unspecified)',
        'Created',
        'Last activity',
        'Expected close',
        'Days since activity',
        'Data as of',
        'Reason for review'
      ],
      ...records.map((r) => [
            r.id,
            r.lead.customerName,
            r.lead.phone,
            branches[r.branchId] ?? r.branchId,
            reps[r.repId] ?? r.repId,
            r.vehicleModel,
            r.source ?? '',
            r.lead.status.rawValue,
            r.dealValue,
            _date(r.lead.createdAt),
            _date(r.lead.lastActivityAt),
            _date(r.lead.expectedCloseDate),
            r.daysSinceLastActivity,
            _date(r.context.snapshotDate),
            reasons[r.id] ?? reason
          ]),
    ];
    final slug = label
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return CsvExport(
        filename:
            '${slug.isEmpty ? 'opportunities' : slug}-${activeOnly ? 'follow-up' : 'records'}.csv',
        content:
            '\uFEFF${rows.map((row) => row.map(_cell).join(',')).join('\r\n')}\r\n',
        count: records.length);
  }

  static String _date(DateTime d) => d.toIso8601String().substring(0, 10);
  static String _cell(Object? value) {
    var text = value?.toString() ?? '';
    // CSV quoting alone does not prevent spreadsheet formula execution.
    if (value is String && RegExp(r'^\s*[=+@\-\t\r\n]').hasMatch(text)) {
      text = "'$text";
    }
    return '"${text.replaceAll('"', '""')}"';
  }
}
