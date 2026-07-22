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
    final ordersAsync = ref.watch(ordersStreamProvider);
    final grouped = ref.watch(ordersByStatusProvider);
    final filteredCount =
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
        data: (all) {
          // Nothing in the DB at all → the first-run empty state (no filters).
          if (all.isEmpty) {
            return _EmptyState(
                icon: Icons.dashboard_customize_outlined,
                message: l.ordersEmpty);
          }
          return Column(
            children: [
              const _FilterHeader(),
              Expanded(
                child: filteredCount == 0
                    ? _EmptyState(
                        icon: Icons.search_off, message: l.ordersNoMatch)
                    : SingleChildScrollView(
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
                            // Cancelled orders only appear once there are any —
                            // keeps the board clean but leaves them reachable.
                            if ((grouped['cancelled'] ?? const []).isNotEmpty)
                              _KanbanColumn(
                                status: 'cancelled',
                                orders: grouped['cancelled']!,
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Search box + channel/payment filter chips above the board.
class _FilterHeader extends ConsumerStatefulWidget {
  const _FilterHeader();

  @override
  ConsumerState<_FilterHeader> createState() => _FilterHeaderState();
}

class _FilterHeaderState extends ConsumerState<_FilterHeader> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(orderSearchProvider);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearAll() {
    _search.clear();
    ref.read(orderSearchProvider.notifier).state = '';
    ref.read(orderChannelFilterProvider.notifier).state = null;
    ref.read(orderPaymentFilterProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final active = ref.watch(ordersFilterActiveProvider);
    final channel = ref.watch(orderChannelFilterProvider);
    final payment = ref.watch(orderPaymentFilterProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _search,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              hintText: l.ordersSearchHint,
              suffixIcon: active
                  ? IconButton(
                      tooltip: l.ordersClearFilters,
                      icon: const Icon(Icons.clear),
                      onPressed: _clearAll,
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) =>
                ref.read(orderSearchProvider.notifier).state = v,
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: l.categoryAll,
                  selected: channel == null,
                  onSelected: () => ref
                      .read(orderChannelFilterProvider.notifier)
                      .state = null,
                ),
                for (final c in orderChannels)
                  _FilterChip(
                    label: orderChannelLabel(l, c),
                    selected: channel == c,
                    onSelected: () => ref
                        .read(orderChannelFilterProvider.notifier)
                        .state = c,
                  ),
                const SizedBox(width: 12),
                for (final p in const ['unpaid', 'partial', 'paid'])
                  _FilterChip(
                    label: orderPaymentLabel(l, p),
                    selected: payment == p,
                    onSelected: () => ref
                        .read(orderPaymentFilterProvider.notifier)
                        .state = (payment == p ? null : p),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        visualDensity: VisualDensity.compact,
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

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = _cardBody(context, ref);
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

  Widget _cardBody(BuildContext context, WidgetRef ref) {
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
                  // Quick-move without opening the full detail sheet — the
                  // drag gesture above does the same thing but isn't always
                  // discoverable, especially on a small phone screen.
                  if (order.status != 'cancelled')
                    _QuickMoveMenu(order: order, ref: ref),
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
              if ((order.trackingNumber ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.local_shipping_outlined,
                        size: 12, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        deliveryStatusLabel(
                            l, order.deliveryStatus ?? 'pending'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact "..." menu on a Kanban card — moves the order's status in one tap,
/// without opening the full detail sheet.
class _QuickMoveMenu extends StatelessWidget {
  const _QuickMoveMenu({required this.order, required this.ref});
  final Order order;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18),
      padding: EdgeInsets.zero,
      tooltip: l.orderMoveTo,
      onSelected: (status) =>
          ref.read(ordersRepositoryProvider).setStatus(order.id, status),
      itemBuilder: (context) => [
        for (final s in orderStatuses)
          if (s != order.status)
            PopupMenuItem(
              value: s,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: orderStatusColor(s), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(orderStatusLabel(l, s)),
                ],
              ),
            ),
      ],
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
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
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
