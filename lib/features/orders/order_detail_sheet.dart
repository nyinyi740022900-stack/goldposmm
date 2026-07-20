import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/local/database.dart';
import '../../l10n/app_localizations.dart';
import '../sell/payment_labels.dart';
import '../sell/sales_providers.dart';
import 'order_editor_sheet.dart';
import 'order_labels.dart';
import 'orders_providers.dart';
import 'orders_repository.dart';

/// Read-only order view with pipeline actions (edit, move, convert, cancel,
/// delete). Reads the live order from the stream so it reflects edits/moves.
class OrderDetailSheet extends ConsumerWidget {
  const OrderDetailSheet({super.key, required this.orderId});

  final String orderId;

  static Future<void> show(BuildContext context, String orderId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => OrderDetailSheet(orderId: orderId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final sym = l.currencySymbol;
    final orders = ref.watch(ordersStreamProvider).valueOrNull ?? const [];
    Order? order;
    for (final o in orders) {
      if (o.id == orderId) {
        order = o;
        break;
      }
    }
    if (order == null) {
      return const SizedBox(height: 120, child: Center(child: Text('—')));
    }
    final o = order;
    final items = ref.watch(orderItemsProvider(orderId)).valueOrNull ?? const [];
    final repo = ref.read(ordersRepositoryProvider);
    final total = o.itemsTotal + o.deliveryFee;
    final isCancelled = o.status == 'cancelled';
    final canConvert = o.status == 'delivered' && o.saleId == null;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(orderChannelIcon(o.channel), size: 18),
                const SizedBox(width: 6),
                Text(o.orderNo,
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                _StatusChip(status: o.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(orderChannelLabel(l, o.channel),
                style: Theme.of(context).textTheme.bodySmall),
            const Divider(height: 20),
            _kv(context, Icons.person_outline, o.customerName),
            if (o.customerPhone != null && o.customerPhone!.isNotEmpty)
              _kv(context, Icons.phone_outlined, o.customerPhone!),
            if (o.deliveryAddress != null && o.deliveryAddress!.isNotEmpty)
              _kv(context, Icons.location_on_outlined, o.deliveryAddress!),
            if (o.note != null && o.note!.isNotEmpty)
              _kv(context, Icons.sticky_note_2_outlined, o.note!),
            const Divider(height: 20),
            for (final it in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text('${it.nameSnapshot}  ×${it.qty}')),
                    Text(Money(it.lineTotal).withSymbol(sym)),
                  ],
                ),
              ),
            if (o.deliveryFee > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l.orderDeliveryFee),
                    Text(Money(o.deliveryFee).withSymbol(sym)),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l.orderTotal,
                    style: Theme.of(context).textTheme.titleMedium),
                Text(Money(total).withSymbol(sym),
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('${l.orderPayment}: '),
                Text(orderPaymentLabel(l, o.paymentStatus)),
              ],
            ),
            const Divider(height: 24),

            // --- actions ---
            if (!isCancelled) ...[
              Text(l.orderMoveTo,
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in orderStatuses)
                    ChoiceChip(
                      label: Text(orderStatusLabel(l, s)),
                      selected: o.status == s,
                      onSelected: (_) => repo.setStatus(orderId, s),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (canConvert)
              FilledButton.icon(
                onPressed: () => _convert(context, ref, o),
                icon: const Icon(Icons.point_of_sale),
                label: Text(l.orderConvertToSale),
              ),
            if (o.saleId != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 18),
                    const SizedBox(width: 6),
                    Text(l.orderAlreadySale),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: o.saleId != null
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            OrderEditorSheet.show(context,
                                order: o, existingItems: items);
                          },
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l.orderEdit),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => isCancelled
                        ? repo.setStatus(orderId, 'new')
                        : repo.setStatus(orderId, 'cancelled'),
                    icon: Icon(isCancelled
                        ? Icons.restore
                        : Icons.cancel_outlined),
                    label: Text(isCancelled ? l.orderRestore : l.orderCancel),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _confirmDelete(context, ref),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: Text(l.orderDelete,
                  style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _convert(BuildContext context, WidgetRef ref, Order o) async {
    final l = AppLocalizations.of(context);
    final method = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(l.orderPickPaymentMethod,
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(l.orderConvertHint,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            const SizedBox(height: 8),
            for (final m in paymentMethods.where((m) => m != 'credit'))
              ListTile(
                title: Text(paymentLabel(l, m)),
                onTap: () => Navigator.of(context).pop(m),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (method == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final repo = ref.read(ordersRepositoryProvider);
    await repo.convertToSale(o.id, paymentMethod: method);
    final saved = await repo.getOrder(o.id);
    final sale = await ref.read(salesRepositoryProvider).getSale(saved.saleId!);
    if (!context.mounted) return;
    messenger.showSnackBar(
        SnackBar(content: Text(l.orderConverted(sale.invoiceNo))));
    nav.pop();
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(l.orderDeleteConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l.orderDelete)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final nav = Navigator.of(context);
    await ref.read(ordersRepositoryProvider).deleteOrder(orderId);
    if (context.mounted) nav.pop();
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = orderStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(orderStatusLabel(l, status),
          style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
