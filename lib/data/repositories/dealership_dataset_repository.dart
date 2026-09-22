import '../parsing/dealership_dataset_parser.dart';
import '../sources/dealership_data_source.dart';
import '../validation/validation.dart';

abstract interface class DealershipRepository {
  Future<DatasetLoadResult> load();
}

final class DealershipDatasetRepository implements DealershipRepository {
  const DealershipDatasetRepository({
    required this.dataSource,
    this.parser = const DealershipDatasetParser(),
  });

  final DealershipDataSource dataSource;
  final DealershipDatasetParser parser;

  @override
  Future<DatasetLoadResult> load() async =>
      parser.parse(await dataSource.load());
}
