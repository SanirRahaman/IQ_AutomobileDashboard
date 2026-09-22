import 'package:flutter_test/flutter_test.dart';
import 'package:yoyota_dealers/data/repositories/dealership_dataset_repository.dart';
import 'package:yoyota_dealers/data/sources/dealership_data_source.dart';

import '../fixtures/canonical_fixture.dart';

final class _MemoryDataSource implements DealershipDataSource {
  const _MemoryDataSource(this.value);

  final String value;

  @override
  Future<String> load() async => value;
}

void main() {
  test('repository returns one typed canonical dataset', () async {
    final repository = DealershipDatasetRepository(
      dataSource: _MemoryDataSource(canonicalDatasetJson()),
    );

    final result = await repository.load();

    expect(result.isCompatible, isTrue);
    expect(result.dataset!.leads.single.id, 'L1');
  });
}
