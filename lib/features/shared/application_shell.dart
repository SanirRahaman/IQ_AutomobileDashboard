import 'package:flutter/material.dart';
import '../../app/analysis_router.dart';
import '../../app/app_theme.dart';
import '../../app/appearance_controller.dart';
import '../../application/analysis/analysis_controller.dart';
import '../dashboard/dashboard_page.dart';
import '../dashboard/dashboard_view_data.dart';

const _overviewDestination = (
  label: 'Overview',
  path: '/',
  icon: Icons.dashboard_outlined,
  key: 'overview'
);

const _comparisonDestinations = [
  (
    label: 'Vehicle models',
    path: '/compare/models',
    icon: Icons.directions_car_outlined,
    key: 'models'
  ),
  (
    label: 'Branches',
    path: '/compare/branches',
    icon: Icons.store_outlined,
    key: 'branches'
  ),
  (
    label: 'Representatives',
    path: '/compare/representatives',
    icon: Icons.groups_outlined,
    key: 'representatives'
  ),
  (
    label: 'Lead sources',
    path: '/compare/sources',
    icon: Icons.campaign_outlined,
    key: 'sources'
  ),
];

const _monitorDestinations = [
  (
    label: 'Monthly trends',
    path: '/explore/trends',
    icon: Icons.show_chart,
    key: 'trends'
  ),
  (
    label: 'Active pipeline',
    path: '/pipeline',
    icon: Icons.view_kanban_outlined,
    key: 'pipeline'
  ),
  (
    label: 'Deliveries',
    path: '/delivery',
    icon: Icons.local_shipping_outlined,
    key: 'delivery'
  ),
  (
    label: 'Follow-up lists',
    path: '/explore/follow-up',
    icon: Icons.playlist_add_check,
    key: 'followUp'
  ),
];

const _destinations = [
  _overviewDestination,
  ..._comparisonDestinations,
  ..._monitorDestinations,
];

/// One responsive workspace around all existing route content.
class ApplicationShell extends StatelessWidget {
  const ApplicationShell(
      {super.key,
      required this.controller,
      required this.path,
      required this.child});
  final AnalysisController controller;
  final String path;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, constraints) =>
          _buildShell(context, constraints.maxWidth));

  Widget _buildShell(BuildContext context, double width) {
    final appearance = AppearanceScope.of(context);
    final mobile = width < 760;
    final expanded = width >= 1200 && !appearance.collapsed;
    final detail = path.startsWith('/branch/') || path.startsWith('/rep/');
    final title =
        _destinations.where((d) => d.path == path).firstOrNull?.label ??
            (path == '/explore'
                ? 'Vehicle models'
                : path.startsWith('/rep/')
                    ? 'Representative performance'
                    : path.startsWith('/branch/')
                        ? 'Branch performance'
                        : 'Workspace');
    final branch = controller.dataset.branches
        .where((b) => b.id == controller.filters.branchId)
        .firstOrNull;
    final rep = controller.dataset.salesReps
        .where((r) => r.id == controller.filters.repId)
        .firstOrNull;
    final snapshot =
        DashboardPresenter.formatDate(controller.results.performance.snapshot);

    Widget navigation(bool wide, {bool inDrawer = false}) => Container(
          width: wide ? 232 : 76,
          decoration: BoxDecoration(
              color: context.colors.surface,
              border: Border(right: BorderSide(color: context.colors.border))),
          child: SafeArea(
              child: Column(children: [
            SizedBox(
                height: 72,
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(children: [
                      Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                              color: context.colors.brandSoft,
                              borderRadius: BorderRadius.circular(9)),
                          child: Icon(Icons.directions_car_filled_outlined,
                              size: 21, color: context.colors.brand)),
                      if (wide) ...[
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text('yoyotaDealers',
                                style: Theme.of(context).textTheme.titleMedium))
                      ],
                    ]))),
            if (wide)
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('DEALERSHIP PERFORMANCE',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: context.colors.muted)))),
            Expanded(
                child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    children: [
                  _navigationItem(context, _overviewDestination,
                      wide: wide, inDrawer: inDrawer, detail: detail),
                  _navigationLabel(context, 'COMPARE PERFORMANCE', wide),
                  for (final d in _comparisonDestinations)
                    _navigationItem(context, d,
                        wide: wide, inDrawer: inDrawer, detail: detail),
                  _navigationLabel(context, 'MONITOR & ACT', wide),
                  for (final d in _monitorDestinations)
                    _navigationItem(context, d,
                        wide: wide, inDrawer: inDrawer, detail: detail),
                ])),
            if (width >= 1200 && !inDrawer)
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: IconButton(
                      tooltip: expanded ? 'Collapse sidebar' : 'Expand sidebar',
                      onPressed: appearance.toggleSidebar,
                      icon: Icon(expanded
                          ? Icons.keyboard_double_arrow_left
                          : Icons.keyboard_double_arrow_right))),
            if (wide)
              Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Dealership performance',
                      style: Theme.of(context).textTheme.bodySmall)),
          ])),
        );

    return Scaffold(
      drawer: mobile
          ? Drawer(width: 260, child: navigation(true, inDrawer: true))
          : null,
      body: SafeArea(
          child: Row(children: [
        if (!mobile) navigation(expanded),
        Expanded(
            child: Column(children: [
          Container(
              height: 68,
              padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 24),
              decoration: BoxDecoration(
                  color: context.colors.surface,
                  border:
                      Border(bottom: BorderSide(color: context.colors.border))),
              child: Row(children: [
                if (mobile)
                  Builder(
                      builder: (context) => IconButton(
                          key: const Key('open-navigation'),
                          tooltip: 'Open navigation',
                          onPressed: () => Scaffold.of(context).openDrawer(),
                          icon: const Icon(Icons.menu))),
                if (detail)
                  IconButton(
                      tooltip: 'Back',
                      onPressed: () => AppNavigation.up(context),
                      icon: const Icon(Icons.arrow_back, size: 20)),
                Expanded(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium),
                      if (detail)
                        Text(
                            [
                              'Overview',
                              if (branch != null) branch.name,
                              if (rep != null) rep.name
                            ].join(' / '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall),
                    ])),
                PopupMenuButton<ThemeMode>(
                    key: const Key('appearance-menu'),
                    tooltip: 'Appearance: ${appearance.mode.name}',
                    initialValue: appearance.mode,
                    onSelected: appearance.setMode,
                    icon: Icon(appearance.mode == ThemeMode.system
                        ? Icons.brightness_auto_outlined
                        : appearance.mode == ThemeMode.dark
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined),
                    itemBuilder: (_) => [
                          for (final mode in ThemeMode.values)
                            PopupMenuItem(
                                value: mode,
                                child: Row(children: [
                                  Icon(
                                      mode == appearance.mode
                                          ? Icons.check
                                          : Icons.circle_outlined,
                                      size: 16),
                                  const SizedBox(width: 10),
                                  Text(switch (mode) {
                                    ThemeMode.system => 'System',
                                    ThemeMode.light => 'Light',
                                    ThemeMode.dark => 'Dark'
                                  })
                                ]))
                        ]),
              ])),
          DashboardFilterToolbar(controller: controller),
          Expanded(
              child: LayoutBuilder(
                  builder: (context, constraints) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                          size: Size(
                              constraints.maxWidth, constraints.maxHeight)),
                      child: child))),
          Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: mobile ? 16 : 24, vertical: 6),
              child: Text(
                  'Historical data as of $snapshot. Ageing and overdue figures use this date.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center)),
        ])),
      ])),
    );
  }

  Widget _navigationLabel(BuildContext context, String label, bool wide) => wide
      ? Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: Text(label,
              style: TextStyle(
                  color: context.colors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0)))
      : const Divider(height: 18);

  Widget _navigationItem(
    BuildContext context,
    ({IconData icon, String key, String label, String path}) destination, {
    required bool wide,
    required bool inDrawer,
    required bool detail,
  }) {
    final legacySelected =
        path == '/explore' && destination.path == '/compare/models';
    final selected = path == destination.path ||
        legacySelected ||
        detail && destination.path == '/';
    return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Tooltip(
            message: wide ? '' : destination.label,
            child: Semantics(
                selected: selected,
                child: Material(
                    color: selected
                        ? context.colors.brandSoft
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                        key: Key('performance-nav-${destination.key}'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          if (inDrawer) {
                            Navigator.of(context).pop();
                          }
                          if (path != destination.path) {
                            AppNavigation.go(context, destination.path);
                          }
                        },
                        child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: wide ? 12 : 0, vertical: 14),
                            child: Row(
                                mainAxisAlignment: wide
                                    ? MainAxisAlignment.start
                                    : MainAxisAlignment.center,
                                children: [
                                  Icon(destination.icon,
                                      size: 21,
                                      color: selected
                                          ? context.colors.brand
                                          : context.colors.muted),
                                  if (wide) ...[
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Text(destination.label,
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: context.colors.ink,
                                                fontWeight: selected
                                                    ? FontWeight.w700
                                                    : FontWeight.w500)))
                                  ]
                                ])))))));
  }
}
