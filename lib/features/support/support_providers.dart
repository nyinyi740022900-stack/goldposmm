import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../printing/printing_providers.dart';
import 'vendor_config.dart';

final vendorConfigRepositoryProvider = Provider<VendorConfigRepository>((ref) {
  return VendorConfigRepository(ref.watch(settingsRepositoryProvider));
});

/// Company payment accounts + support contact (cached, refreshed when online).
final vendorConfigProvider = FutureProvider<VendorConfig>((ref) {
  return ref.watch(vendorConfigRepositoryProvider).load();
});
