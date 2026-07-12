import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../inventory/inventory_providers.dart';
import '../license/license_providers.dart';
import '../printing/printing_providers.dart';
import 'cart.dart';
import 'checkout_sheet.dart';
import 'sales_providers.dart';

class SellScreen extends ConsumerWidget {
  const SellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final products = ref.watch(productsStreamProvider);
    final filtered = ref.watch(sellProductsProvider);
    final cart = ref.watch(cartProvider);
    final currency = l.currencySymbol;
    final trackStock = ref.watch(trackStockProvider).valueOrNull ?? true;
    final readOnly = ref.watch(licenseControllerProvider).status.isReadOnly &&
        !ref.watch(licenseControllerProvider).loading;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.sellTitle),
        actions: [
          if (!cart.isEmpty)
            IconButton(
              tooltip: l.sellClear,
              icon: const Icon(Icons.remove_shopping_cart),
              onPressed: () => ref.read(cartProvider.notifier).clear(),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppTheme.space4, 0, AppTheme.space4, AppTheme.space2),
            child: TextField(
              decoration: InputDecoration(
                hintText: l.commonSearch,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) =>
                  ref.read(sellSearchProvider.notifier).state = v,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (readOnly)
            Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space3),
                child: Row(
                  children: [
                    Icon(Icons.lock,
                        color: Theme.of(context).colorScheme.onErrorContainer),
                    const SizedBox(width: AppTheme.space2),
                    Expanded(
                      child: Text(
                        l.licenseReadOnly,
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const _SellCategoryFilterBar(),
          Expanded(
            child: products.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (_) {
                if (filtered.isEmpty) {
                  final searching =
                      ref.read(sellSearchProvider).trim().isNotEmpty ||
                          ref.read(sellCategoryProvider) != null;
                  return Center(
                      child: Text(searching
                          ? l.inventoryNoResults
                          : l.inventoryEmpty));
                }
                return GridView.builder(
            padding: const EdgeInsets.all(AppTheme.space3),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              mainAxisSpacing: AppTheme.space3,
              crossAxisSpacing: AppTheme.space3,
              childAspectRatio: 1.1,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final p = filtered[i];
              return _ProductCard(
                name: p.product.name,
                price: Money(p.product.salePrice).withSymbol(currency),
                outOfStock: trackStock && p.quantity <= 0,
                onTap: () =>
                    ref.read(cartProvider.notifier).addProduct(p.product),
              );
            },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : _CartBar(
              itemCount: cart.itemCount,
              total: cart.total.withSymbol(currency),
              onCheckout: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => const CheckoutSheet(),
              ),
            ),
    );
  }
}

class _SellCategoryFilterBar extends ConsumerWidget {
  const _SellCategoryFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final categories =
        ref.watch(categoriesStreamProvider).valueOrNull ?? const [];
    if (categories.isEmpty) return const SizedBox.shrink();
    final selected = ref.watch(sellCategoryProvider);

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.space3),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppTheme.space2),
            child: ChoiceChip(
              label: Text(l.categoryAll),
              selected: selected == null,
              onSelected: (_) =>
                  ref.read(sellCategoryProvider.notifier).state = null,
            ),
          ),
          for (final c in categories)
            Padding(
              padding: const EdgeInsets.only(right: AppTheme.space2),
              child: ChoiceChip(
                label: Text(c.name),
                selected: selected == c.id,
                onSelected: (_) =>
                    ref.read(sellCategoryProvider.notifier).state = c.id,
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.name,
    required this.price,
    required this.outOfStock,
    required this.onTap,
  });

  final String name;
  final String price;
  final bool outOfStock;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: AppTheme.space2),
              Text(price,
                  style: TextStyle(
                      color: scheme.primary, fontWeight: FontWeight.bold)),
              if (outOfStock)
                Text('0',
                    style: TextStyle(
                        color: scheme.error, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  const _CartBar({
    required this.itemCount,
    required this.total,
    required this.onCheckout,
  });

  final int itemCount;
  final String total;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space3),
        child: FilledButton(
          onPressed: onCheckout,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${l.sellCheckout}  ($itemCount)'),
              Text(total, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
