import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/theme/app_theme.dart';
import '../../data/local/database.dart';
import '../../l10n/app_localizations.dart';
import '../credit/credit_providers.dart';
import '../sell/sales_providers.dart';
import 'invoice_detail_screen.dart';

enum InvoiceFilter { all, credit }

final invoiceFilterProvider =
    StateProvider<InvoiceFilter>((ref) => InvoiceFilter.all);

class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final sales = ref.watch(salesStreamProvider);
    final filter = ref.watch(invoiceFilterProvider);
    final owedBySale = ref.watch(creditOwedBySaleProvider);
    final currency = l.currencySymbol;
    // Owed after repayments have been allocated to this invoice.
    int owedOf(Sale s) => owedBySale[s.id] ?? (s.total - s.paid);

    return Scaffold(
      appBar: AppBar(title: Text(l.navInvoices)),
      body: sales.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (all) {
          final list = filter == InvoiceFilter.credit
              ? all.where((s) => owedOf(s) > 0).toList()
              : all;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppTheme.space3),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text(l.invoiceFilterAll),
                      selected: filter == InvoiceFilter.all,
                      onSelected: (_) => ref
                          .read(invoiceFilterProvider.notifier)
                          .state = InvoiceFilter.all,
                    ),
                    const SizedBox(width: AppTheme.space2),
                    ChoiceChip(
                      label: Text(l.invoiceFilterCredit),
                      selected: filter == InvoiceFilter.credit,
                      onSelected: (_) => ref
                          .read(invoiceFilterProvider.notifier)
                          .state = InvoiceFilter.credit,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? Center(child: Text(l.invoicesEmpty))
                    : ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final s = list[i];
                          final owed = owedOf(s);
                          final isCredit = owed > 0;
                          return ListTile(
                            title: Row(
                              children: [
                                Flexible(child: Text(s.invoiceNo)),
                                if (isCredit) ...[
                                  const SizedBox(width: 6),
                                  _CreditBadge(
                                      settled: owed <= 0, label: l.paymentCredit),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              isCredit && s.customerName != null
                                  ? '${DateFormat('yyyy-MM-dd HH:mm').format(s.finalizedAt)} · ${s.customerName}'
                                  : DateFormat('yyyy-MM-dd HH:mm')
                                      .format(s.finalizedAt),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  Money(s.total).withSymbol(currency),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                if (isCredit && owed > 0)
                                  Text(
                                    l.invoiceOwed(
                                        Money(owed).withSymbol(currency)),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            Theme.of(context).colorScheme.error),
                                  ),
                              ],
                            ),
                            onTap: () =>
                                Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) =>
                                  InvoiceDetailScreen(saleId: s.id),
                            )),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CreditBadge extends StatelessWidget {
  const _CreditBadge({required this.settled, required this.label});
  final bool settled;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = settled ? Colors.green : Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}
