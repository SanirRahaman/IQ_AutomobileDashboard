import 'package:flutter_test/flutter_test.dart';
import 'package:yoyota_dealers/app/analysis_router.dart';
import 'package:yoyota_dealers/application/analysis/analysis_controller.dart';
import 'package:yoyota_dealers/application/analysis/analysis_filters.dart';
import 'package:yoyota_dealers/data/models/dealership_models.dart';
import '../fixtures/analytics_fixture.dart';

void main() {
  late AnalysisController c;
  late AnalysisRouter r;
  setUp(() {
    c = AnalysisController(
        dataset: dataset(leads: [
      lead(
          id: 'A',
          status: LeadStatus.newLead,
          journey: [history(LeadStatus.newLead, day(1))])
    ]));
    r = AnalysisRouter(c);
  });
  tearDown(() {
    r.dispose();
    c.dispose();
  });
  test('filter changes report URL configuration; reset cleans query', () {
    c.setBranch('B1');
    expect(r.currentConfiguration.queryParameters['branch'], 'B1');
    c.setDateRange(AnalysisDateRange(start: day(1), end: day(31)));
    expect(r.currentConfiguration.queryParameters['from'], '2025-01-01');
    c.setSalesRep('R1');
    expect(r.currentConfiguration.queryParameters['rep'], 'R1');
    c.reset();
    expect(r.currentConfiguration.toString(), '/');
  });
  test('exploration page restores its filters and retains the route on reset',
      () async {
    r.go('/explore');
    c.setBranch('B1');
    c.setVehicleModel('Model A');
    final uri = r.currentConfiguration;
    expect(uri.path, '/explore');
    final fresh = AnalysisController(dataset: c.dataset);
    final router = AnalysisRouter(fresh);
    await router.setNewRoutePath(uri);
    expect(fresh.filters, c.filters);
    fresh.reset();
    expect(router.currentConfiguration.toString(), '/explore');
    router.dispose();
    fresh.dispose();
  });
  test(
      'browser route restoration and back/forward do not feed back or lose scope',
      () async {
    c.setBranch('B1');
    final previous = r.currentConfiguration;
    c.setSalesRep('R1');
    final next = r.currentConfiguration;
    await r.setNewRoutePath(previous);
    expect(c.filters.repId, isNull);
    expect(c.filters.branchId, 'B1');
    await r.setNewRoutePath(next);
    expect(c.filters.repId, 'R1');
    expect(r.currentConfiguration, next);
    final fresh = AnalysisController(dataset: c.dataset);
    final freshRouter = AnalysisRouter(fresh);
    await freshRouter.setNewRoutePath(next);
    expect(fresh.filters, c.filters);
    freshRouter.dispose();
    fresh.dispose();
  });
  test('drill-down and parent links retain period and dimensions', () async {
    c.setDateRange(AnalysisDateRange(start: day(1), end: day(31)));
    c.setSource('web');
    r.go('/branch/B1');
    r.go('/rep/R1');
    expect(c.filters.repId, 'R1');
    r.up();
    expect(r.currentConfiguration.path, '/branch/B1');
    expect(c.filters.source, 'web');
    expect(c.filters.repId, isNull);
    r.up();
    expect(r.currentConfiguration.path, '/');
    expect(c.filters.branchId, isNull);
    expect(c.filters.dateRange!.end, day(31));
  });
  test(
      'invalid dates and dimensions fail safely; unknown entity stays not-found route',
      () async {
    await r.setNewRoutePath(Uri.parse(
        '/?branch=missing&rep=missing&from=2025-02-30&to=2025-03-01&model=missing&status=missing'));
    expect(c.filters.isDefault, isTrue);
    await r.setNewRoutePath(Uri.parse('/branch/missing'));
    expect(r.currentConfiguration.path, '/branch/missing');
    expect(c.filters.branchId, isNull);
  });
}
