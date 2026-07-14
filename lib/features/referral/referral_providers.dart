import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'referral_repository.dart';

final referralRepositoryProvider =
    Provider<ReferralRepository>((ref) => ReferralRepository());

/// Earnings + own code for the current shop. Auto-disposes so it re-fetches
/// each time the screen opens (and after a redeem via `invalidate`).
final referralSummaryProvider =
    FutureProvider.autoDispose<ReferralSummary>((ref) {
  return ref.watch(referralRepositoryProvider).summary();
});

final referredShopsProvider =
    FutureProvider.autoDispose<List<ReferredShop>>((ref) {
  return ref.watch(referralRepositoryProvider).referredShops();
});
