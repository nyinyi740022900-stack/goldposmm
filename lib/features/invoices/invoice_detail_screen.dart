import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../printing/print_action.dart';
import '../sell/payment_labels.dart';
import '../sell/sales_providers.dart';

class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen({super.key, required this.saleId});

  final String saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final detail = ref.watch(saleDetailProvider(saleId));
    final currency = l.currencySymbol;

    return Scaffold(
      appBar: AppBar(title: Text(l.invoiceDetail)),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (d) {
          final s = d.sale;
          return ListView(
            padding: const EdgeInsets.all(AppTheme.space4),
            children: [
              Text(s.invoiceNo,
                  style: Theme.of(context).textTheme.titleLarge),
              Text(DateFormat('yyyy-MM-dd HH:mm').format(s.finalizedAt)),
              const Divider(height: AppTheme.space5),
              ...d.items.map((it) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                              '${it.nameSnapshot}\n${it.qty} x ${Money(it.priceSnapshot).formatted}'),
                        ),
                        Text(Money(it.lineTotal).withSymbol(currency)),
                      ],
                    ),
                  )),
              const Divider(height: AppTheme.space5),
              _row(context, l.sellSubtotal,
                  Money(s.subtotal).withSymbol(currency)),
              if (s.discount > 0)
                _row(context, l.sellDiscount,
                    '-${Money(s.discount).withSymbol(currency)}'),
              _row(context, l.commonTotal, Money(s.total).withSymbol(currency),
                  bold: true),
              _row(context, l.sellPaymentMethod,
                  paymentLabel(l, s.paymentMethod)),
              const SizedBox(height: AppTheme.space5),
              FilledButton.icon(
                onPressed: () => printSaleReceipt(context, ref,
                    sale: s, items: d.items),
                icon: const Icon(Icons.print),
                label: Text(l.invoiceReprint),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {bool bold = false}) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.bold) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}
