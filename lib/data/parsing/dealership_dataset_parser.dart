import 'dart:convert';

import '../models/dealership_models.dart';
import '../validation/validation.dart';

/// Converts only the canonical dealership JSON schema into typed entities.
final class DealershipDatasetParser {
  const DealershipDatasetParser({
    this.validator = const DealershipDatasetValidator(),
  });

  final DealershipDatasetValidator validator;

  DatasetLoadResult parse(String source) {
    late final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      return _fatal(
        ValidationCode.invalidJson,
        'The dataset is not valid JSON: ${error.message}',
        r'$',
      );
    }

    try {
      final root = _Reader.object(decoded, r'$');
      final dataset = DealershipDataset(
        metadata: _metadata(_Reader.requiredObject(root, 'metadata', r'$')),
        branches: _Reader.requiredList(root, 'branches', r'$')
            .indexed
            .map((item) => _branch(
                  _Reader.object(item.$2, r'$.branches' '[${item.$1}]'),
                  r'$.branches' '[${item.$1}]',
                ))
            .toList(),
        salesReps: _Reader.requiredList(root, 'sales_reps', r'$')
            .indexed
            .map((item) => _salesRep(
                  _Reader.object(item.$2, r'$.sales_reps' '[${item.$1}]'),
                  r'$.sales_reps' '[${item.$1}]',
                ))
            .toList(),
        leads: _Reader.requiredList(root, 'leads', r'$')
            .indexed
            .map((item) => _lead(
                  _Reader.object(item.$2, r'$.leads' '[${item.$1}]'),
                  r'$.leads' '[${item.$1}]',
                ))
            .toList(),
        targets: _Reader.requiredList(root, 'targets', r'$')
            .indexed
            .map((item) => _target(
                  _Reader.object(item.$2, r'$.targets' '[${item.$1}]'),
                  r'$.targets' '[${item.$1}]',
                ))
            .toList(),
        deliveries: _Reader.requiredList(root, 'deliveries', r'$')
            .indexed
            .map((item) => _delivery(
                  _Reader.object(item.$2, r'$.deliveries' '[${item.$1}]'),
                  r'$.deliveries' '[${item.$1}]',
                ))
            .toList(),
      );
      return DatasetLoadResult(
        dataset: dataset,
        report: ValidationReport(validator.validate(dataset)),
      );
    } on _ParseFailure catch (failure) {
      return _fatal(failure.code, failure.message, failure.path);
    }
  }

  DealershipMetadata _metadata(Map<String, Object?> map) {
    const path = r'$.metadata';
    return DealershipMetadata(
      generatedAt: _Reader.date(map, 'generated_at', path),
      description: _Reader.string(map, 'description', path),
      dateRange: _Reader.string(map, 'date_range', path),
      notes: _Reader.string(map, 'notes', path),
    );
  }

  Branch _branch(Map<String, Object?> map, String path) => Branch(
        id: _Reader.string(map, 'id', path),
        name: _Reader.string(map, 'name', path),
        city: _Reader.string(map, 'city', path),
      );

  SalesRep _salesRep(Map<String, Object?> map, String path) => SalesRep(
        id: _Reader.string(map, 'id', path),
        name: _Reader.string(map, 'name', path),
        branchId: _Reader.string(map, 'branch_id', path),
        role: SalesRepRoleValue.fromRaw(_Reader.string(map, 'role', path)),
        joined: _Reader.date(map, 'joined', path),
      );

  Lead _lead(Map<String, Object?> map, String path) {
    final history =
        _Reader.requiredList(map, 'status_history', path).indexed.map((item) {
      final entryPath = '$path.status_history[${item.$1}]';
      final entry = _Reader.object(item.$2, entryPath);
      return LeadStatusHistoryEntry(
        status:
            LeadStatusValue.fromRaw(_Reader.string(entry, 'status', entryPath)),
        timestamp: _Reader.date(entry, 'timestamp', entryPath),
        note: _Reader.optionalString(entry, 'note', entryPath),
      );
    }).toList();

    return Lead(
      id: _Reader.string(map, 'id', path),
      customerName: _Reader.string(map, 'customer_name', path),
      phone: _Reader.string(map, 'phone', path),
      source: _Reader.optionalString(map, 'source', path),
      modelInterested: _Reader.string(map, 'model_interested', path),
      status: LeadStatusValue.fromRaw(_Reader.string(map, 'status', path)),
      assignedTo: _Reader.string(map, 'assigned_to', path),
      branchId: _Reader.string(map, 'branch_id', path),
      createdAt: _Reader.date(map, 'created_at', path),
      lastActivityAt: _Reader.date(map, 'last_activity_at', path),
      statusHistory: history,
      expectedCloseDate: _Reader.date(map, 'expected_close_date', path),
      dealValue: _Reader.number(map, 'deal_value', path),
      lostReason: _Reader.optionalString(map, 'lost_reason', path),
    );
  }

  Target _target(Map<String, Object?> map, String path) => Target(
        branchId: _Reader.string(map, 'branch_id', path),
        month: _Reader.month(map, 'month', path),
        targetUnits: _Reader.integer(map, 'target_units', path),
        targetRevenue: _Reader.number(map, 'target_revenue', path),
      );

  Delivery _delivery(Map<String, Object?> map, String path) => Delivery(
        leadId: _Reader.string(map, 'lead_id', path),
        orderDate: _Reader.date(map, 'order_date', path),
        deliveryDate: _Reader.date(map, 'delivery_date', path),
        daysToDeliver: _Reader.integer(map, 'days_to_deliver', path),
        delayReason: _Reader.optionalString(map, 'delay_reason', path),
      );

  DatasetLoadResult _fatal(
    ValidationCode code,
    String message,
    String path,
  ) =>
      DatasetLoadResult(
        dataset: null,
        report: ValidationReport([
          ValidationIssue(
            code: code,
            severity: ValidationSeverity.fatal,
            message: message,
            path: path,
          ),
        ]),
      );
}

final class _Reader {
  static Map<String, Object?> object(Object? value, String path) {
    if (value is! Map<String, dynamic>) {
      throw _ParseFailure(
        ValidationCode.incompatibleSchema,
        'Expected an object at $path.',
        path,
      );
    }
    return value;
  }

  static Map<String, Object?> requiredObject(
    Map<String, Object?> map,
    String key,
    String parentPath,
  ) =>
      object(_required(map, key, parentPath), '$parentPath.$key');

  static List<Object?> requiredList(
    Map<String, Object?> map,
    String key,
    String parentPath,
  ) {
    final value = _required(map, key, parentPath);
    if (value is! List) {
      throw _ParseFailure(
        ValidationCode.incompatibleSchema,
        'Expected an array at $parentPath.$key.',
        '$parentPath.$key',
      );
    }
    return value.cast<Object?>();
  }

  static String string(
    Map<String, Object?> map,
    String key,
    String parentPath,
  ) {
    final value = _required(map, key, parentPath);
    if (value is! String) {
      throw _ParseFailure(
        ValidationCode.malformedType,
        'Expected a string at $parentPath.$key.',
        '$parentPath.$key',
      );
    }
    return value;
  }

  static String? optionalString(
    Map<String, Object?> map,
    String key,
    String parentPath,
  ) {
    if (!map.containsKey(key) || map[key] == null) return null;
    return string(map, key, parentPath);
  }

  static num number(
    Map<String, Object?> map,
    String key,
    String parentPath,
  ) {
    final value = _required(map, key, parentPath);
    if (value is! num || !value.isFinite) {
      throw _ParseFailure(
        ValidationCode.malformedNumber,
        'Expected a finite number at $parentPath.$key.',
        '$parentPath.$key',
      );
    }
    return value;
  }

  static int integer(
    Map<String, Object?> map,
    String key,
    String parentPath,
  ) {
    final value = _required(map, key, parentPath);
    if (value is! int) {
      throw _ParseFailure(
        ValidationCode.malformedNumber,
        'Expected an integer at $parentPath.$key.',
        '$parentPath.$key',
      );
    }
    return value;
  }

  static DateTime date(
    Map<String, Object?> map,
    String key,
    String parentPath,
  ) {
    final raw = string(map, key, parentPath);
    final value = DateTime.tryParse(raw);
    if (value == null) {
      throw _ParseFailure(
        ValidationCode.malformedDate,
        'Malformed date "$raw" at $parentPath.$key.',
        '$parentPath.$key',
      );
    }
    return value;
  }

  static DateTime month(
    Map<String, Object?> map,
    String key,
    String parentPath,
  ) {
    final raw = string(map, key, parentPath);
    if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(raw)) {
      throw _ParseFailure(
        ValidationCode.malformedDate,
        'Malformed month "$raw" at $parentPath.$key; expected YYYY-MM.',
        '$parentPath.$key',
      );
    }
    return DateTime.parse('$raw-01');
  }

  static Object? _required(
    Map<String, Object?> map,
    String key,
    String parentPath,
  ) {
    if (!map.containsKey(key) || map[key] == null) {
      throw _ParseFailure(
        ValidationCode.missingField,
        'Missing required field $parentPath.$key.',
        '$parentPath.$key',
      );
    }
    return map[key];
  }
}

final class _ParseFailure implements Exception {
  const _ParseFailure(this.code, this.message, this.path);

  final ValidationCode code;
  final String message;
  final String path;
}
