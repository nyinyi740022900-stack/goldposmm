import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/database.dart';

/// Single app-wide Drift database instance.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// The active shop id. Set at license activation (Phase 5). For local-only
/// development we use a fixed demo shop so rows have a valid scope.
final shopIdProvider = StateProvider<String>(
  (ref) => kDebugMode ? 'demo-shop' : '',
);
