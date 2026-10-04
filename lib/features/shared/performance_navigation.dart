import 'package:flutter/material.dart';

import '../../analytics/services/performance_explorer.dart';

enum PerformanceSection {
  overview('Overview', '/', Icons.dashboard_outlined),
  compareModels(
      'Vehicle models', '/compare/models', Icons.directions_car_outlined),
  compareBranches('Branches', '/compare/branches', Icons.store_outlined),
  compareRepresentatives(
      'Representatives', '/compare/representatives', Icons.groups_outlined),
  compareSources('Lead sources', '/compare/sources', Icons.campaign_outlined),
  trends('Monthly trends', '/explore/trends', Icons.show_chart),
  followUp('Follow-up lists', '/explore/follow-up', Icons.list_alt);

  const PerformanceSection(this.label, this.path, this.icon);
  final String label;
  final String path;
  final IconData icon;

  ComparisonDimension? get comparisonDimension => switch (this) {
        PerformanceSection.compareModels => ComparisonDimension.model,
        PerformanceSection.compareBranches => ComparisonDimension.branch,
        PerformanceSection.compareRepresentatives =>
          ComparisonDimension.representative,
        PerformanceSection.compareSources => ComparisonDimension.source,
        _ => null,
      };

  bool get isComparison => comparisonDimension != null;
}
