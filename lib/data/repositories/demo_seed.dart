import '../local/database.dart';
import 'inventory_repository.dart';

/// Seeds a handful of typical Myanmar minimart products for first-run/demo.
/// Idempotent-ish: only seeds when the products table is empty for the shop.
class DemoSeed {
  DemoSeed(this._db, this._repo);

  final AppDatabase _db;
  final InventoryRepository _repo;

  Future<void> ensureSeeded() async {
    final existing = await _db.select(_db.products).get();
    if (existing.isNotEmpty) return;

    const items = <_SeedItem>[
      _SeedItem('ကိုကာကိုလာ (ဗူး)', 'Coca-Cola can', 700, 550, 24, 6),
      _SeedItem('ရွှေဖီ ကော်ဖီမစ်', '3-in-1 coffee', 300, 220, 100, 20),
      _SeedItem('အုန်းနို့ ဘီစကွတ်', 'Coconut biscuit', 500, 380, 40, 10),
      _SeedItem('ရေသန့် (၁ လီတာ)', 'Drinking water 1L', 400, 250, 60, 12),
      _SeedItem('မီးခြစ်', 'Match box', 100, 60, 200, 30),
      _SeedItem('ဆပ်ပြာ', 'Bar soap', 800, 600, 30, 8),
    ];

    for (final it in items) {
      await _repo.upsertProduct(
        name: it.name,
        sku: it.sku,
        salePrice: it.sale,
        costPrice: it.cost,
        quantity: it.qty,
        reorderLevel: it.reorder,
      );
    }
  }
}

class _SeedItem {
  final String name;
  final String sku;
  final int sale;
  final int cost;
  final int qty;
  final int reorder;
  const _SeedItem(
      this.name, this.sku, this.sale, this.cost, this.qty, this.reorder);
}
