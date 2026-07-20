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

/// Board search query (matches customer name, phone, or order number).
final orderSearchProvider = StateProvider<String>((ref) => '');

/// Channel filter (`null` = all channels).
final orderChannelFilterProvider = StateProvider<String?>((ref) => null);

/// Payment-status filter (`null` = all).
final orderPaymentFilterProvider = StateProvider<String?>((ref) => null);

/// True when any search/filter is narrowing the board (drives a clear button).
final ordersFilterActiveProvider = Provider<bool>((ref) {
  return ref.watch(orderSearchProvider).trim().isNotEmpty ||
      ref.watch(orderChannelFilterProvider) != null ||
      ref.watch(orderPaymentFilterProvider) != null;
});

/// Orders grouped by status, after applying the search + filters. Includes the
/// pipeline columns ([orderStatuses]) plus a `cancelled` bucket so cancelled
/// orders stay reachable (to restore or delete) instead of vanishing.
final ordersByStatusProvider = Provider<Map<String, List<Order>>>((ref) {
  final all = ref.watch(ordersStreamProvider).valueOrNull ?? const [];
  return groupOrdersForBoard(
    all,
    query: ref.watch(orderSearchProvider),
    channel: ref.watch(orderChannelFilterProvider),
    payment: ref.watch(orderPaymentFilterProvider),
  );
});

/// Pure: filters [orders] by search/channel/payment and buckets them by status
/// (the pipeline columns plus `cancelled`). Kept side-effect-free so it can be
/// unit-tested without Riverpod. [query] matches customer name, phone, or
/// order number (case-insensitive).
Map<String, List<Order>> groupOrdersForBoard(
  List<Order> orders, {
  String query = '',
  String? channel,
  String? payment,
}) {
  final q = query.trim().toLowerCase();
  final map = {
    for (final s in orderStatuses) s: <Order>[],
    'cancelled': <Order>[],
  };
  for (final o in orders) {
    if (channel != null && o.channel != channel) continue;
    if (payment != null && o.paymentStatus != payment) continue;
    if (q.isNotEmpty) {
      final hay = '${o.customerName} ${o.customerPhone ?? ''} ${o.orderNo}'
          .toLowerCase();
      if (!hay.contains(q)) continue;
    }
    (map[o.status])?.add(o);
  }
  return map;
}

/// Items for one order (for the detail / editor sheet).
final orderItemsProvider =
    FutureProvider.family<List<OrderItem>, String>((ref, orderId) async {
  return ref.watch(ordersRepositoryProvider).items(orderId);
});
