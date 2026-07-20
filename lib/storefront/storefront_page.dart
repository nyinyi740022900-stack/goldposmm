import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'storefront_api.dart';

final _money = NumberFormat('#,##0', 'en_US');
String _ks(int v) => '${_money.format(v)} Ks';

/// The public storefront for one shop, addressed by [slug]. Shows the catalog,
/// a cart, and a guest-checkout form that submits an order (no account needed).
class StorefrontPage extends StatefulWidget {
  const StorefrontPage({super.key, required this.slug});
  final String slug;

  @override
  State<StorefrontPage> createState() => _StorefrontPageState();
}

class _StorefrontPageState extends State<StorefrontPage> {
  final _api = StorefrontApi();
  late Future<Catalog> _future;
  final Map<String, int> _cart = {}; // productId -> qty
  late Map<String, StoreProduct> _byId = {};

  @override
  void initState() {
    super.initState();
    _future = _api.fetchCatalog(widget.slug);
  }

  int get _total => _cart.entries
      .fold(0, (s, e) => s + (_byId[e.key]?.price ?? 0) * e.value);
  int get _count => _cart.values.fold(0, (s, q) => s + q);

  void _add(StoreProduct p) => setState(() => _cart[p.id] = (_cart[p.id] ?? 0) + 1);
  void _sub(StoreProduct p) => setState(() {
        final q = (_cart[p.id] ?? 0) - 1;
        if (q <= 0) {
          _cart.remove(p.id);
        } else {
          _cart[p.id] = q;
        }
      });

  Future<void> _checkout(Catalog catalog) async {
    final lines = _cart.entries
        .map((e) => OrderLine(
            e.key, _byId[e.key]!.name, _byId[e.key]!.price, e.value))
        .toList();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CheckoutSheet(
        slug: widget.slug,
        api: _api,
        info: catalog.info,
        lines: lines,
        total: _total,
      ),
    );
    if (result != null && mounted) {
      setState(() => _cart.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Catalog>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _NotFound(slug: widget.slug);
          }
          final catalog = snap.data!;
          _byId = {for (final p in catalog.products) p.id: p};
          return CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: Text(catalog.info.displayName ?? 'Shop'),
              ),
              if ((catalog.info.address ?? '').isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(children: [
                      const Icon(Icons.location_on_outlined, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text(catalog.info.address!)),
                    ]),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.all(12),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final p = catalog.products[i];
                      return _ProductCard(
                        product: p,
                        qty: _cart[p.id] ?? 0,
                        onAdd: () => _add(p),
                        onSub: () => _sub(p),
                      );
                    },
                    childCount: catalog.products.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _count == 0
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: () => _future.then((c) => _checkout(c)),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('Checkout · $_count item(s) · ${_ks(_total)}'),
                  ),
                ),
              ),
            ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.qty,
    required this.onAdd,
    required this.onSub,
  });
  final StoreProduct product;
  final int qty;
  final VoidCallback onAdd;
  final VoidCallback onSub;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Row(
              children: [
                Text(_ks(product.price),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                if (qty == 0)
                  FilledButton.tonal(
                    onPressed: onAdd,
                    child: const Text('Add'),
                  )
                else
                  Row(
                    children: [
                      IconButton.filledTonal(
                          onPressed: onSub,
                          icon: const Icon(Icons.remove, size: 18)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('$qty',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                      ),
                      IconButton.filledTonal(
                          onPressed: onAdd,
                          icon: const Icon(Icons.add, size: 18)),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutSheet extends StatefulWidget {
  const _CheckoutSheet({
    required this.slug,
    required this.api,
    required this.info,
    required this.lines,
    required this.total,
  });
  final String slug;
  final StorefrontApi api;
  final StoreInfo info;
  final List<OrderLine> lines;
  final int total;

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _note = TextEditingController();
  bool _submitting = false;
  String? _orderNo;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      final no = await widget.api.submitOrder(
        slug: widget.slug,
        customerName: _name.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        note: _note.text.trim(),
        lines: widget.lines,
      );
      if (mounted) setState(() => _orderNo = no);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    if (_orderNo != null) return _confirmation(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Your details',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name *')),
            const SizedBox(height: 8),
            TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: 8),
            TextField(
                controller: _address,
                maxLines: 2,
                decoration:
                    const InputDecoration(labelText: 'Delivery address')),
            const SizedBox(height: 8),
            TextField(
                controller: _note,
                decoration: const InputDecoration(labelText: 'Note')),
            const SizedBox(height: 16),
            Text('Total: ${_ks(widget.total)}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Place order'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _confirmation(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 56),
          const SizedBox(height: 12),
          Text('Order placed!',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Order no: $_orderNo'),
          const SizedBox(height: 16),
          if ((widget.info.payKpay ?? '').isNotEmpty ||
              (widget.info.payWave ?? '').isNotEmpty) ...[
            const Text('Transfer and send the screenshot to the shop:'),
            const SizedBox(height: 8),
            if ((widget.info.payKpay ?? '').isNotEmpty)
              Text('KBZPay: ${widget.info.payKpay}'),
            if ((widget.info.payWave ?? '').isNotEmpty)
              Text('WavePay: ${widget.info.payWave}'),
            const SizedBox(height: 16),
          ],
          FilledButton(
            onPressed: () => Navigator.of(context).pop('done'),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.storefront_outlined, size: 56),
          const SizedBox(height: 12),
          Text('Shop "$slug" not found or not published.'),
        ],
      ),
    );
  }
}
