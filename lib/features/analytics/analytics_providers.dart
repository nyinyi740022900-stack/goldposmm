import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/repositories/analytics_repository.dart';
import '../sell/sales_providers.dart';
import 'analytics_calculator.dart';

enum AnalyticsRange { today, week, month }

final analyticsRangeProvider =
    StateProvider<AnalyticsRange>((ref) => AnalyticsRange.week);

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(
      ref.watch(databaseProvider), ref.watch(shopIdProvider));
});

/// (start, end-exclusive) bounds for a range, aligned to day boundaries.
({DateTime start, DateTime end}) rangeBounds(AnalyticsRange r, DateTime now) {
  final todayStart = DateTime(now.year, now.month, now.day);
  final tomorrow = todayStart.add(const Duration(days: 1));
  return switch (r) {
    AnalyticsRange.today => (start: todayStart, end: tomorrow),
    AnalyticsRange.week => (
        start: todayStart.subtract(const Duration(days: 6)),
        end: tomorrow
      ),
    AnalyticsRange.month => (
        start: todayStart.subtract(const Duration(days: 29)),
        end: tomorrow
      ),
  };
}

final analyticsSummaryProvider = FutureProvider<AnalyticsSummary>((ref) async {
  // Recompute whenever sales change so the dashboard stays live.
  ref.watch(salesStreamProvider);
  final range = ref.watch(analyticsRangeProvider);
  final bounds = rangeBounds(range, DateTime.now());
  return ref
      .watch(analyticsRepositoryProvider)
      .summary(bounds.start, bounds.end);
});
