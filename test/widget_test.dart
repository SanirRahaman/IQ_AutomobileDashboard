import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yoyota_dealers/app/yoyota_dealers_app.dart';
import 'package:yoyota_dealers/application/analysis/analysis_controller.dart';
import 'package:yoyota_dealers/data/parsing/dealership_dataset_parser.dart';

import 'fixtures/canonical_fixture.dart';

void main() {
  testWidgets('incoming URL survives asynchronous dataset loading and refresh',
      (tester) async {
    final dataset =
        const DealershipDatasetParser().parse(canonicalDatasetJson()).dataset!;
    final branch = dataset.branches.first.id;
    final uri = Uri(path: '/', queryParameters: {
      'branch': branch,
      'from': '2025-01-01',
      'to': '2025-01-31'
    });
    final pending = Completer<AnalysisController>();
    final controller = AnalysisController(dataset: dataset);
    await tester.pumpWidget(YoyotaDealersApp(
        initialUri: uri, loadController: () => pending.future));
    expect(find.text('Preparing dealership analysis…'), findsOneWidget);
    pending.complete(controller);
    await tester.pumpAndSettle();
    expect(controller.filters.branchId, branch);
    expect(controller.filters.dateRange!.start, DateTime.utc(2025, 1, 1));
    expect(find.text('Sales performance'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    final refreshed = AnalysisController(dataset: dataset);
    await tester.pumpWidget(YoyotaDealersApp(
        initialUri: uri, loadController: () => Future.value(refreshed)));
    await tester.pumpAndSettle();
    expect(refreshed.filters.branchId, branch);
    expect(refreshed.filters.dateRange!.end, DateTime.utc(2025, 1, 31));
  });

  testWidgets('dataset failure shows retry and recovers without losing URL',
      (tester) async {
    final dataset =
        const DealershipDatasetParser().parse(canonicalDatasetJson()).dataset!;
    var attempts = 0;
    final controller = AnalysisController(dataset: dataset);
    await tester.pumpWidget(YoyotaDealersApp(
        initialUri: Uri(
            path: '/', queryParameters: {'branch': dataset.branches.first.id}),
        loadController: () {
          attempts++;
          return attempts == 1
              ? Future.error(StateError('Test load failure'))
              : Future.value(controller);
        }));
    await tester.pumpAndSettle();
    expect(find.text('The dataset could not be loaded'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Sales performance'), findsOneWidget);
    expect(controller.filters.branchId, dataset.branches.first.id);
  });

  testWidgets('shows the supplied dashboard controller', (tester) async {
    final dataset =
        const DealershipDatasetParser().parse(canonicalDatasetJson()).dataset!;
    final controller = AnalysisController(dataset: dataset);
    addTearDown(controller.dispose);
    await tester.pumpWidget(YoyotaDealersApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('Sales performance'), findsOneWidget);
  });
}
