import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../application/analysis/analysis_controller.dart';
import '../application/analysis/analysis_filters.dart';
import '../application/analysis/analysis_route_codec.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/investigation/investigation_page.dart';
import '../features/operations/operational_pages.dart';

class AnalysisRouteParser extends RouteInformationParser<Uri> {
  const AnalysisRouteParser();
  @override
  Future<Uri> parseRouteInformation(RouteInformation routeInformation) =>
      SynchronousFuture(routeInformation.uri);
  @override
  RouteInformation restoreRouteInformation(Uri configuration) =>
      RouteInformation(uri: configuration);
}

/// One Flutter Router owns navigation and URL state. Applying browser history
/// suppresses controller-to-URL feedback; user changes report a new configuration.
class AnalysisRouter extends RouterDelegate<Uri>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<Uri> {
  AnalysisRouter(this.controller) {
    controller.addListener(_filtersChanged);
  }
  final AnalysisController controller;
  static const codec = AnalysisRouteCodec();
  @override
  final navigatorKey = GlobalKey<NavigatorState>();
  Uri _uri = Uri(path: '/');
  bool _restoring = false;
  @override
  Uri get currentConfiguration => _uri;

  void _filtersChanged() {
    if (_restoring) return;
    _uri = codec.encode(controller.filters, path: _uri.path);
    notifyListeners();
  }

  @override
  Future<void> setNewRoutePath(Uri configuration) {
    _restoring = true;
    controller.applyRoute(configuration);
    // Keep unknown entity paths so they show a useful not-found view.
    _uri = codec.encode(controller.filters,
        path: configuration.path.isEmpty ? '/' : configuration.path);
    _restoring = false;
    notifyListeners();
    return SynchronousFuture(null);
  }

  void go(String path, {AnalysisFilters? filters}) {
    final uri = codec.encode(filters ?? controller.filters, path: path);
    setNewRoutePath(uri);
  }

  void up() {
    final parts = _uri.pathSegments;
    if (parts.length == 2 && parts.first == 'rep') {
      final branch = controller.filters.branchId;
      go(branch == null ? '/' : '/branch/${Uri.encodeComponent(branch)}',
          filters: controller.filters.copyWith(repId: null));
    } else {
      go('/',
          filters: controller.filters.copyWith(branchId: null, repId: null));
    }
  }

  @override
  Future<bool> popRoute() {
    if (navigatorKey!.currentState?.canPop() == true) {
      navigatorKey!.currentState!.pop();
      return SynchronousFuture(true);
    }
    if (_uri.path == '/') return SynchronousFuture(false);
    up();
    return SynchronousFuture(true);
  }

  @override
  Widget build(BuildContext context) {
    final parts = _uri.pathSegments;
    final key = ValueKey(_uri.toString());
    Widget page;
    if (parts.length == 2 && parts.first == 'branch') {
      page = BranchDetailPage(
          key: key, baseController: controller, branchId: parts[1]);
    } else if (parts.length == 2 && parts.first == 'rep') {
      page =
          RepDetailPage(key: key, baseController: controller, repId: parts[1]);
    } else if (_uri.path == '/pipeline') {
      page = PipelinePage(controller: controller);
    } else if (_uri.path == '/delivery') {
      page = DeliveryPage(controller: controller);
    } else if (_uri.path == '/') {
      page = DashboardPage(controller: controller);
    } else {
      page = Scaffold(
          body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('This page was not found.'),
        TextButton(
            onPressed: () => go('/'), child: const Text('Return to dashboard')),
      ])));
    }
    return Navigator(
      key: navigatorKey,
      pages: [MaterialPage<void>(key: ValueKey(_uri.path), child: page)],
      onDidRemovePage: (_) {},
    );
  }

  @override
  void dispose() {
    controller.removeListener(_filtersChanged);
    super.dispose();
  }
}

abstract final class AppNavigation {
  static void go(BuildContext context, String path,
      {AnalysisFilters? filters}) {
    final router = Router.of(context);
    Router.navigate(
        context,
        () => (router.routerDelegate as AnalysisRouter)
            .go(path, filters: filters));
  }

  static void up(BuildContext context) {
    final router = Router.of(context);
    Router.navigate(
        context, () => (router.routerDelegate as AnalysisRouter).up());
  }
}
