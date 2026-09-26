import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../application/analysis/analysis_controller.dart';
import '../data/repositories/dealership_dataset_repository.dart';
import '../data/sources/dealership_data_source.dart';
import 'analysis_router.dart';
import 'app_theme.dart';
import 'appearance_controller.dart';

class YoyotaDealersApp extends StatefulWidget {
  const YoyotaDealersApp(
      {super.key, this.controller, this.initialUri, this.loadController});

  final AnalysisController? controller;
  final Uri? initialUri;
  final Future<AnalysisController> Function()? loadController;

  @override
  State<YoyotaDealersApp> createState() => _YoyotaDealersAppState();
}

class _YoyotaDealersAppState extends State<YoyotaDealersApp> {
  final _appearance = AppearanceController();
  AnalysisController? _loadedController;
  Object? _error;
  AnalysisRouter? _router;
  late final PlatformRouteInformationProvider _routeProvider;

  AnalysisController? get _controller => widget.controller ?? _loadedController;

  @override
  void initState() {
    super.initState();
    // Capture the incoming location before asynchronous asset loading. A
    // temporary Navigator-based loading app would consume/reset the route.
    final base = Uri.base;
    final initial = widget.initialUri ??
        (kIsWeb
            ? (base.fragment.startsWith('/')
                ? Uri.tryParse(base.fragment) ?? Uri(path: '/')
                : Uri(
                    path: base.path, query: base.hasQuery ? base.query : null))
            : Uri(path: '/'));
    _routeProvider = PlatformRouteInformationProvider(
        initialRouteInformation: RouteInformation(uri: initial));
    if (widget.controller == null) _load();
  }

  Future<void> _load() async {
    try {
      final controller = await (widget.loadController?.call() ??
          AnalysisController.load(
            const DealershipDatasetRepository(
              dataSource: AssetDealershipDataSource(),
            ),
          ));
      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() => _loadedController = controller);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _appearance.dispose();
    _routeProvider.dispose();
    _router?.dispose();
    _loadedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppearanceScope(
      controller: _appearance,
      child: ListenableBuilder(
          listenable: _appearance,
          builder: (context, _) => _buildApp(context)));

  Widget _buildApp(BuildContext context) {
    final controller = _controller;
    if (_error != null || controller == null) {
      return MaterialApp.router(
        routeInformationProvider: _routeProvider,
        routeInformationParser: const AnalysisRouteParser(),
        title: 'yoyotaDealers',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        darkTheme: buildAppTheme(brightness: Brightness.dark),
        themeMode: _appearance.mode,
        themeAnimationDuration:
            (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
                ? Duration.zero
                : const Duration(milliseconds: 150),
        routerDelegate: _LoadingRouter(_error == null
            ? const _DashboardLoadingState()
            : _DatasetErrorState(error: _error!, onRetry: _retry)),
      );
    }

    if (_router == null) {
      _router = AnalysisRouter(controller);
      // Swapping a RouterDelegate does not reparse its provider automatically.
      // Restore before the first dashboard frame (also after a failed load).
      _router!.setNewRoutePath(_routeProvider.value.uri);
    }
    return MaterialApp.router(
      title: 'yoyotaDealers',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(brightness: Brightness.dark),
      themeMode: _appearance.mode,
      themeAnimationDuration:
          (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
              ? Duration.zero
              : const Duration(milliseconds: 150),
      routeInformationProvider: _routeProvider,
      routerDelegate: _router!,
      routeInformationParser: const AnalysisRouteParser(),
      // Flutter's default hash URL strategy supports static hosting refreshes.
    );
  }

  void _retry() {
    _loadedController?.dispose();
    setState(() {
      _loadedController = null;
      _error = null;
    });
    _load();
  }
}

class _DashboardLoadingState extends StatelessWidget {
  const _DashboardLoadingState();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          label: 'Loading dealership analysis',
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              SizedBox(height: 18),
              Text('Preparing dealership analysis…'),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatasetErrorState extends StatelessWidget {
  const _DatasetErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 42, color: context.colors.brand),
                    const SizedBox(height: 16),
                    Text('The dataset could not be loaded',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(error.toString(),
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingRouter extends RouterDelegate<Uri> with ChangeNotifier {
  _LoadingRouter(this.page);
  final Widget page;
  @override
  Widget build(BuildContext context) => page;
  @override
  Future<void> setNewRoutePath(Uri configuration) => SynchronousFuture(null);
  @override
  Future<bool> popRoute() => SynchronousFuture(false);
}
