import 'package:flutter/services.dart' show AssetBundle, rootBundle;

abstract interface class DealershipDataSource {
  Future<String> load();
}

final class AssetDealershipDataSource implements DealershipDataSource {
  const AssetDealershipDataSource({
    this.assetPath = 'assets/data/dealership_data.json',
    this.bundle,
  });

  final String assetPath;
  final AssetBundle? bundle;

  @override
  Future<String> load() => (bundle ?? rootBundle).loadString(assetPath);
}
