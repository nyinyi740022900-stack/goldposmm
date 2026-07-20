import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/local/database.dart';
import 'orders_repository.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final shopId = ref.watch(shopIdProvider);
  return OrdersRepository(db, shopId);
});

/// All non-deleted orders for the shop, newest-updated first. The Kanban board
/// groups these by [Order.status] client-side.
final ordersStreamProvider = StreamProvider<List<Order>>((ref) {
  return ref.watch(ordersRepositoryProvider).watchOrders();
});

/// Orders grouped into the Kanban columns (in [orderStatuses] order).
final ordersByStatusProvider = Provider<Map<String, List<Order>>>((ref) {
  final all = ref.watch(ordersStreamProvider).valueOrNull ?? const [];
  final map = {for (final s in orderStatuses) s: <Order>[]};
  for (final o in all) {
    // Cancelled orders stay off the board.
    (map[o.status])?.add(o);
  }
  return map;
});

/// Items for one order (for the detail / editor sheet).
final orderItemsProvider =
    FutureProvider.family<List<OrderItem>, String>((ref, orderId) async {
  return ref.watch(ordersRepositoryProvider).items(orderId);
});
