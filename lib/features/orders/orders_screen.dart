import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/local/database.dart';
import '../../l10n/app_localizations.dart';
import 'order_detail_sheet.dart';
import 'order_editor_sheet.dart';
import 'order_labels.dart';
import 'orders_providers.dart';
import 'orders_repository.dart';

/// The Social Order Kanban board: one horizontally-scrolling column per
/// pipeline stage. Drag a card onto another column to change its status; tap a
/// card for details + actions.
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final grouped = ref.watch(ordersByStatusProvider);
    final ordersAsync = ref.watch(ordersStreamProvider);
    final totalCount =
        grouped.values.fold<int>(0, (s, list) => s + list.length);

    return Scaffold(
      appBar: AppBar(title: Text(l.ordersTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => OrderEditorSheet.show(context),
        icon: const Icon(Icons.add),
        label: Text(l.orderNew),
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (_) {
          if (totalCount == 0) {
            return _EmptyState(message: l.ordersEmpty);
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final status in orderStatuses)
                  _KanbanColumn(
                    status: status,
                    orders: grouped[status] ?? const [],
                  ),
                // Cancelled orders only appear once there are any — keeps the
                // board clean but leaves them reachable to restore/delete.
                if ((grouped['cancelled'] ?? const []).isNotEmpty)
                  _KanbanColumn(
                    status: 'cancelled',
                    orders: grouped['cancelled']!,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _KanbanColumn extends ConsumerWidget {
  const _KanbanColumn({required this.status, required this.orders});

  final String status;
  final List<Order> orders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final color = orderStatusColor(status);
    return DragTarget<Order>(
      onWillAcceptWithDetails: (d) => d.data.status != status,
      onAcceptWithDetails: (d) =>
          ref.read(ordersRepositoryProvider).setStatus(d.data.id, status),
      builder: (context, candidate, rejected) {
        final highlight = candidate.isNotEmpty;
        return Container(
          width: 264,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: highlight
                ? color.withValues(alpha: 0.10)
                : Theme.of(context).colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: highlight
                ? Border.all(color: color, width: 1.5)
                : Border.all(color: Colors.transparent, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(orderStatusLabel(l, status),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    Text('${orders.length}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              if (orders.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Icon(Icons.inbox_outlined,
                      color: Theme.of(context).colorScheme.outlineVariant),
                )
              else
                ...orders.map((o) => _OrderCard(order: o)),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final card = _cardBody(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: LongPressDraggable<Order>(
        data: order,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(width: 240, child: card),
        ),
        childWhenDragging: Opacity(opacity: 0.4, child: card),
        child: card,
      ),
    );
  }

  Widget _cardBody(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sym = l.currencySymbol;
    final total = order.itemsTotal + order.deliveryFee;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => OrderDetailSheet.show(context, order.id),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(orderChannelIcon(order.channel),
                      size: 14, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(order.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(order.orderNo,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(Money(total).withSymbol(sym),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  _PayDot(status: order.paymentStatus),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayDot extends StatelessWidget {
  const _PayDot({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = switch (status) {
      'paid' => Colors.green,
      'partial' => Colors.orange,
      _ => Theme.of(context).colorScheme.outline,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 4),
        Text(orderPaymentLabel(l, status),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.dashboard_customize_outlined,
              size: 56, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
