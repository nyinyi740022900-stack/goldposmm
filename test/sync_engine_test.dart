import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_pos/data/local/database.dart';
import 'package:mm_pos/data/repositories/inventory_repository.dart';
import 'package:mm_pos/data/repositories/settings_repository.dart';
import 'package:mm_pos/data/sync/sync_engine.dart';

/// In-memory fake backend: store[table][id] = row map.
class FakeSyncRemote implements SyncRemote {
  final Map<String, Map<String, Map<String, dynamic>>> store = {};

  @override
  Future<void> upsert(String table, Map<String, dynamic> row) async {
    (store[table] ??= {})[row['id'] as String] = Map.of(row);
  }

  @override
  Future<void> markDeleted(String table, String id, DateTime updatedAt) async {
    final row = store[table]?[id];
    if (row != null) {
      row['is_deleted'] = true;
      row['updated_at'] = updatedAt.toUtc().toIso8601String();
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchChanges(
      String table, String shopId, DateTime? since) async {
    final rows = (store[table] ?? {})
        .values
        .where((r) =>
            r['shop_id'] == shopId &&
            (since == null ||
                DateTime.parse(r['updated_at'] as String).isAfter(since)))
        .map((e) => Map<String, dynamic>.from(e))
        .toList()
      ..sort((a, b) => DateTime.parse(a['updated_at'] as String)
          .compareTo(DateTime.parse(b['updated_at'] as String)));
    return rows;
  }
}

Map<String, dynamic> remoteProduct(
  String id, {
  String shop = 'shop-1',
  String name = 'Remote item',
  int price = 500,
  required DateTime updatedAt,
  bool deleted = false,
}) {
  final iso = updatedAt.toUtc().toIso8601String();
  return {
    'id': id,
    'shop_id': shop,
    'name': name,
    'sku': null,
    'barcode': null,
    'category_id': null,
    'cost_price': 0,
    'sale_price': price,
    'unit': 'pcs',
    'image_path': null,
    'is_active': true,
    'created_at': iso,
    'updated_at': iso,
    'is_deleted': deleted,
  };
}

void main() {
  late AppDatabase db;
  late InventoryRepository inventory;
  late SettingsRepository settings;
  late FakeSyncRemote remote;
  late SyncEngine engine;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    inventory = InventoryRepository(db, 'shop-1');
    settings = SettingsRepository(db);
    remote = FakeSyncRemote();
    engine = SyncEngine(
        db: db, remote: remote, settings: settings, shopId: 'shop-1');
  });

  tearDown(() async => db.close());

  test('push drains outbox and uploads product + stock rows', () async {
    await inventory.upsertProduct(name: 'Coke', salePrice: 700, quantity: 10);

    final result = await engine.syncNow();

    expect(result.pushed, greaterThanOrEqualTo(2));
    expect(remote.store['products'], isNotNull);
    expect(remote.store['products']!.values.single['name'], 'Coke');
    expect(remote.store['stock_levels']!.values.single['quantity'], 10);

    // Outbox emptied.
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test('pull inserts new remote rows locally', () async {
    remote.store['products'] = {
      'p1': remoteProduct('p1', name: 'From cloud', updatedAt: DateTime.now()),
    };

    await engine.syncNow();

    final local = await inventory.watchProducts().first;
    expect(local.map((p) => p.product.name), contains('From cloud'));
  });

  test('last-write-wins: newer local edit is not overwritten by older remote',
      () async {
    // Local product created now.
    final id =
        await inventory.upsertProduct(name: 'Local name', salePrice: 100);
    // Older remote version of the same id.
    remote.store['products'] = {
      id: remoteProduct(id,
          name: 'Old remote name',
          updatedAt: DateTime.now().subtract(const Duration(days: 1))),
    };

    await engine.syncNow();

    final local = (await inventory.watchProducts().first).single;
    expect(local.product.name, 'Local name');
  });

  test('pull cursor advances so unchanged rows are not re-pulled', () async {
    remote.store['products'] = {
      'p1': remoteProduct('p1', updatedAt: DateTime.now()),
    };
    final first = await engine.syncNow();
    expect(first.pulled, greaterThanOrEqualTo(1));

    // Nothing changed remotely -> second sync pulls zero.
    final second = await engine.syncNow();
    expect(second.pulled, 0);
  });

  test('delete is pushed as a tombstone', () async {
    final id = await inventory.upsertProduct(name: 'Temp', salePrice: 1);
    await engine.syncNow(); // push create
    await inventory.deleteProduct(id);
    await engine.syncNow(); // push delete

    expect(remote.store['products']![id]!['is_deleted'], true);
  });
}
