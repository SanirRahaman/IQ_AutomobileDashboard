import 'package:flutter/material.dart';

enum PerformanceSection {
  overview('Overview', '/', Icons.dashboard_outlined),
  comparisons('Comparisons', '/explore', Icons.bar_chart),
  trends('Monthly trends', '/explore/trends', Icons.show_chart),
  followUp('Follow-up lists', '/explore/follow-up', Icons.list_alt);

  const PerformanceSection(this.label, this.path, this.icon);
  final String label;
  final String path;
  final IconData icon;
}
