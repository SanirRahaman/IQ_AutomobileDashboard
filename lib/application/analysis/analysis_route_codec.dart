import '../../data/models/dealership_models.dart';
import 'analysis_filters.dart';

final class AnalysisRouteCodec {
  const AnalysisRouteCodec();

  AnalysisFilters decode(Uri uri, DealershipDataset dataset) {
    String? branchId = uri.queryParameters['branch'];
    String? repId = uri.queryParameters['rep'];
    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments.first == 'branch') {
      branchId = segments[1];
      repId = null;
    } else if (segments.length >= 2 && segments.first == 'rep') {
      repId = segments[1];
      branchId = dataset.salesReps
          .where((rep) => rep.id == repId)
          .map((rep) => rep.branchId)
          .firstOrNull;
    }
    return AnalysisFilters(
      dateRange: _dateRange(uri.queryParameters),
      branchId: branchId,
      repId: repId,
      source:
          dataset.leads.any((l) => l.source == uri.queryParameters['source'])
              ? uri.queryParameters['source']
              : null,
      vehicleModel: dataset.leads
              .any((l) => l.modelInterested == uri.queryParameters['model'])
          ? uri.queryParameters['model']
          : null,
      leadStatus: dataset.leads
              .any((l) => l.status.rawValue == uri.queryParameters['status'])
          ? uri.queryParameters['status']
          : null,
    );
  }

  Uri encode(AnalysisFilters filters, {String? path}) {
    path ??= filters.repId != null
        ? '/rep/${Uri.encodeComponent(filters.repId!)}'
        : filters.branchId != null
            ? '/branch/${Uri.encodeComponent(filters.branchId!)}'
            : '/';
    final query = <String, String>{
      if (!path.startsWith('/branch/') &&
          !path.startsWith('/rep/') &&
          filters.branchId != null)
        'branch': filters.branchId!,
      if (!path.startsWith('/rep/') &&
          !path.startsWith('/branch/') &&
          filters.repId != null)
        'rep': filters.repId!,
      if (filters.dateRange != null) ...{
        'from': _formatDate(filters.dateRange!.start),
        'to': _formatDate(filters.dateRange!.end),
      },
      if (filters.source != null) 'source': filters.source!,
      if (filters.vehicleModel != null) 'model': filters.vehicleModel!,
      if (filters.leadStatus != null) 'status': filters.leadStatus!,
    };
    return Uri(path: path, queryParameters: query.isEmpty ? null : query);
  }

  AnalysisDateRange? _dateRange(Map<String, String> parameters) {
    final from = parameters['from'];
    final to = parameters['to'];
    if (from == null || to == null) return null;
    final start = _strictDate(from);
    final end = _strictDate(to);
    if (start == null || end == null || end.isBefore(start)) return null;
    return AnalysisDateRange(start: start, end: end);
  }

  DateTime? _strictDate(String raw) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) return null;
    final date = DateTime.tryParse('${raw}T00:00:00Z');
    return date != null && _formatDate(date) == raw ? date : null;
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
