import '../models/dealership_models.dart';

enum ValidationSeverity { fatal, error, warning }

enum ValidationCode {
  invalidJson,
  incompatibleSchema,
  missingField,
  malformedType,
  malformedDate,
  malformedNumber,
  duplicateId,
  missingBranchReference,
  missingSalesRepReference,
  missingLeadReference,
  negativeValue,
  emptyStatusHistory,
  malformedStatusHistory,
  unorderedStatusHistory,
  currentStatusConflict,
  unknownEnumValue,
}

final class ValidationIssue {
  const ValidationIssue({
    required this.code,
    required this.severity,
    required this.message,
    required this.path,
    this.recordId,
  });

  final ValidationCode code;
  final ValidationSeverity severity;
  final String message;
  final String path;
  final String? recordId;
}

final class ValidationReport {
  ValidationReport([Iterable<ValidationIssue> issues = const []])
      : issues = List.unmodifiable(issues);

  final List<ValidationIssue> issues;

  Iterable<ValidationIssue> get fatalParsingErrors =>
      issues.where((issue) => issue.severity == ValidationSeverity.fatal);
  Iterable<ValidationIssue> get errors =>
      issues.where((issue) => issue.severity == ValidationSeverity.error);
  Iterable<ValidationIssue> get warnings =>
      issues.where((issue) => issue.severity == ValidationSeverity.warning);
  bool get hasFatalErrors => fatalParsingErrors.isNotEmpty;
  bool get hasErrors => errors.isNotEmpty;
}

final class DatasetLoadResult {
  const DatasetLoadResult({required this.dataset, required this.report});

  final DealershipDataset? dataset;
  final ValidationReport report;

  bool get isCompatible => dataset != null && !report.hasFatalErrors;
}

final class DealershipDatasetValidator {
  const DealershipDatasetValidator();

  List<ValidationIssue> validate(DealershipDataset dataset) {
    final issues = <ValidationIssue>[];
    _duplicates(dataset.branches.map((item) => item.id), 'branches', issues);
    _duplicates(dataset.salesReps.map((item) => item.id), 'sales_reps', issues);
    _duplicates(dataset.leads.map((item) => item.id), 'leads', issues);

    final branchIds = dataset.branches.map((item) => item.id).toSet();
    final repIds = dataset.salesReps.map((item) => item.id).toSet();
    final leadIds = dataset.leads.map((item) => item.id).toSet();

    for (var index = 0; index < dataset.salesReps.length; index++) {
      final rep = dataset.salesReps[index];
      if (!branchIds.contains(rep.branchId)) {
        issues.add(_error(
          ValidationCode.missingBranchReference,
          'Sales rep ${rep.id} references unknown branch ${rep.branchId}.',
          r'$.sales_reps' '[$index].branch_id',
          rep.id,
        ));
      }
      if (!rep.role.isKnown) {
        issues.add(_unknown('role', rep.role.rawValue,
            r'$.sales_reps' '[$index].role', rep.id));
      }
    }

    for (var index = 0; index < dataset.leads.length; index++) {
      final lead = dataset.leads[index];
      final path = r'$.leads' '[$index]';
      if (!branchIds.contains(lead.branchId)) {
        issues.add(_error(
          ValidationCode.missingBranchReference,
          'Lead ${lead.id} references unknown branch ${lead.branchId}.',
          '$path.branch_id',
          lead.id,
        ));
      }
      if (!repIds.contains(lead.assignedTo)) {
        issues.add(_error(
          ValidationCode.missingSalesRepReference,
          'Lead ${lead.id} references unknown sales rep ${lead.assignedTo}.',
          '$path.assigned_to',
          lead.id,
        ));
      }
      if (lead.dealValue < 0) {
        issues.add(_negative('$path.deal_value', lead.id));
      }
      if (!lead.status.isKnown) {
        issues.add(
            _unknown('status', lead.status.rawValue, '$path.status', lead.id));
      }
      if (lead.statusHistory.isEmpty) {
        issues.add(_error(
          ValidationCode.emptyStatusHistory,
          'Lead ${lead.id} has an empty status history.',
          '$path.status_history',
          lead.id,
        ));
        continue;
      }
      for (var historyIndex = 0;
          historyIndex < lead.statusHistory.length;
          historyIndex++) {
        final entry = lead.statusHistory[historyIndex];
        if (!entry.status.isKnown) {
          issues.add(_unknown(
            'status',
            entry.status.rawValue,
            '$path.status_history[$historyIndex].status',
            lead.id,
          ));
        }
        if (historyIndex > 0 &&
            entry.timestamp
                .isBefore(lead.statusHistory[historyIndex - 1].timestamp)) {
          issues.add(_error(
            ValidationCode.unorderedStatusHistory,
            'Lead ${lead.id} status history is not chronological.',
            '$path.status_history[$historyIndex].timestamp',
            lead.id,
          ));
        }
      }
      final finalStatus = lead.statusHistory.last.status;
      if (finalStatus.rawValue != lead.status.rawValue) {
        issues.add(ValidationIssue(
          code: ValidationCode.currentStatusConflict,
          severity: ValidationSeverity.warning,
          message:
              'Lead ${lead.id} current status ${lead.status.rawValue} conflicts '
              'with final history status ${finalStatus.rawValue}.',
          path: '$path.status',
          recordId: lead.id,
        ));
      }
    }

    for (var index = 0; index < dataset.targets.length; index++) {
      final target = dataset.targets[index];
      if (!branchIds.contains(target.branchId)) {
        issues.add(_error(
          ValidationCode.missingBranchReference,
          'Target references unknown branch ${target.branchId}.',
          r'$.targets' '[$index].branch_id',
          target.branchId,
        ));
      }
      if (target.targetUnits < 0) {
        issues.add(_negative(r'$.targets' '[$index].target_units'));
      }
      if (target.targetRevenue < 0) {
        issues.add(_negative(r'$.targets' '[$index].target_revenue'));
      }
    }

    for (var index = 0; index < dataset.deliveries.length; index++) {
      final delivery = dataset.deliveries[index];
      if (!leadIds.contains(delivery.leadId)) {
        issues.add(_error(
          ValidationCode.missingLeadReference,
          'Delivery references unknown lead ${delivery.leadId}.',
          r'$.deliveries' '[$index].lead_id',
          delivery.leadId,
        ));
      }
      if (delivery.daysToDeliver < 0) {
        issues.add(_negative(
            r'$.deliveries' '[$index].days_to_deliver', delivery.leadId));
      }
    }
    return issues;
  }

  void _duplicates(
    Iterable<String> ids,
    String collection,
    List<ValidationIssue> issues,
  ) {
    final seen = <String>{};
    for (final id in ids) {
      if (!seen.add(id)) {
        issues.add(_error(
          ValidationCode.duplicateId,
          'Duplicate ID $id in $collection.',
          '\$.$collection',
          id,
        ));
      }
    }
  }

  ValidationIssue _error(
    ValidationCode code,
    String message,
    String path, [
    String? recordId,
  ]) =>
      ValidationIssue(
        code: code,
        severity: ValidationSeverity.error,
        message: message,
        path: path,
        recordId: recordId,
      );

  ValidationIssue _negative(String path, [String? recordId]) => _error(
        ValidationCode.negativeValue,
        'Value cannot be negative.',
        path,
        recordId,
      );

  ValidationIssue _unknown(
    String field,
    String value,
    String path,
    String? recordId,
  ) =>
      ValidationIssue(
        code: ValidationCode.unknownEnumValue,
        severity: ValidationSeverity.warning,
        message: 'Unknown $field value "$value" was preserved.',
        path: path,
        recordId: recordId,
      );
}
