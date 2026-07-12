import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../license/license_providers.dart';
import '../printing/print_action.dart';
import '../printing/printing_providers.dart';
import 'cart.dart';
import 'payment_labels.dart';
import 'sales_providers.dart';

class CheckoutSheet extends ConsumerStatefulWidget {
  const CheckoutSheet({super.key});

  @override
  ConsumerState<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends ConsumerState<CheckoutSheet> {
  String _method = 'cash';
  final _paid = TextEditingController();
  final _customer = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _paid.dispose();
    _customer.dispose();
    super.dispose();
  }

  int get _paidAmount => int.tryParse(_paid.text.trim()) ?? 0;

  Future<void> _confirm(CartState cart, int total) async {
    final l = AppLocalizations.of(context);

    // License gate: no finalizing sales once past the grace period.
    if (!ref.read(licenseControllerProvider).canSell) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.licenseReadOnly)),
      );
      return;
    }

    final isCredit = _method == 'credit';
    // Cash and credit take an explicit amount (credit may be a partial
    // down-payment, or 0); other digital methods assume exact settlement.
    final paid = (_method == 'cash' || isCredit) ? _paidAmount : total;
    if (_method == 'cash' && paid < total) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.sellInsufficientPaid)),
      );
      return;
    }
    if (isCredit && _customer.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.creditCustomerRequired)),
      );
      return;
    }

    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final salesRepo = ref.read(salesRepositoryProvider);
      final result = await salesRepo.finalizeSale(
        cart: cart,
        paymentMethod: _method,
        paid: paid,
        customerName: isCredit ? _customer.text.trim() : null,
        trackStock: ref.read(trackStockProvider).valueOrNull ?? true,
      );

      // Auto-print the receipt if a printer is configured (done before the
      // sheet closes so the context is still valid).
      final config = await ref.read(settingsRepositoryProvider).printerConfig();
      if (config.hasPrinter && mounted) {
        final sale = await salesRepo.getSale(result.saleId);
        final items = await salesRepo.saleItems(result.saleId);
        if (mounted) {
          await printSaleReceipt(context, ref, sale: sale, items: items);
        }
      }

      ref.read(cartProvider.notifier).clear();
      if (mounted) Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(l.sellCompleted)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cart = ref.watch(cartProvider);
    final currency = l.currencySymbol;
    final total = cart.total.kyat;
    final change =
        _method == 'cash' && _paidAmount > total ? _paidAmount - total : 0;

    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.space4,
        right: AppTheme.space4,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppTheme.space4,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.sellCheckout,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppTheme.space3),

            // Cart lines with qty steppers.
            ...cart.lines.map((line) => _CartLineTile(
                  line: line,
                  currency: currency,
                  onInc: () => ref
                      .read(cartProvider.notifier)
                      .increment(line.product.id),
                  onDec: () => ref
                      .read(cartProvider.notifier)
                      .decrement(line.product.id),
                )),
            const Divider(),

            _row(l.sellSubtotal, cart.subtotal.withSymbol(currency)),
            _DiscountField(
              onChanged: (v) =>
                  ref.read(cartProvider.notifier).setDiscount(v),
            ),
            _row(l.commonTotal, Money(total).withSymbol(currency), bold: true),
            const SizedBox(height: AppTheme.space3),

            Text(l.sellPaymentMethod,
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppTheme.space2),
            Wrap(
              spacing: AppTheme.space2,
              children: [
                for (final m in paymentMethods)
                  ChoiceChip(
                    label: Text(paymentLabel(l, m)),
                    selected: _method == m,
                    onSelected: (_) => setState(() => _method = m),
                  ),
              ],
            ),

            if (_method == 'cash') ...[
              const SizedBox(height: AppTheme.space3),
              TextField(
                controller: _paid,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: l.sellAmountPaid),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppTheme.space2),
              _row(l.sellChange, Money(change).withSymbol(currency)),
            ],

            if (_method == 'credit') ...[
              const SizedBox(height: AppTheme.space3),
              TextField(
                controller: _customer,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: l.creditCustomerName),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppTheme.space2),
              TextField(
                controller: _paid,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: l.creditPaidNow),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppTheme.space2),
              _row(
                l.creditOwed,
                Money(total - _paidAmount < 0 ? 0 : total - _paidAmount)
                    .withSymbol(currency),
                bold: true,
              ),
            ],

            const SizedBox(height: AppTheme.space4),
            FilledButton.icon(
              onPressed:
                  _submitting || cart.isEmpty ? null : () => _confirm(cart, total),
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_circle),
              label: Text(l.sellConfirm),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final style = bold
        ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.line,
    required this.currency,
    required this.onInc,
    required this.onDec,
  });

  final CartLine line;
  final String currency;
  final VoidCallback onInc;
  final VoidCallback onDec;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(line.product.name)),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: onDec,
          ),
          Text('${line.qty}'),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_circle_outline),
            onPressed: onInc,
          ),
          SizedBox(
            width: 90,
            child: Text(
              line.lineTotal.withSymbol(currency),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscountField extends StatelessWidget {
  const _DiscountField({required this.onChanged});

  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(l.sellDiscount)),
          SizedBox(
            width: 120,
            child: TextField(
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                isDense: true,
                hintText: '0',
              ),
              onChanged: (v) => onChanged(int.tryParse(v.trim()) ?? 0),
            ),
          ),
        ],
      ),
    );
  }
}
