import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_pos/data/local/database.dart';
import 'package:mm_pos/data/sync/sync_mappers.dart';
import 'package:mm_pos/features/orders/orders_repository.dart';

/// payment_method ('transfer'|'cod') is set exclusively by the storefront
/// Edge Function and only ever read on-device — this covers the sync mapper
/// round-trip (toRemote includes it; upsertLocal applies an incoming value),
/// the exact code path added alongside the storefront checkout change.
void main() {
  late AppDatabase db;
  late OrdersRepository orders;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    orders = OrdersRepository(db, 'shop-1');
  });

  tearDown(() async => db.close());

  SyncTableDef ordersDef() =>
      syncTables.firstWhere((t) => t.name == 'orders');

  test('toRemote includes payment_method', () async {
    final id = await orders.saveOrder(
      customerName: 'Web Customer',
      channel: 'storefront',
      lines: const [OrderDraftLine(name: 'Item', price: 500, qty: 1)],
    );
    final remote = await ordersDef().toRemote(db, id);
    expect(remote, isNotNull);
    expect(remote!.containsKey('payment_method'), isTrue);
  });

  test('upsertLocal applies an incoming payment_method (cod)', () async {
    final id = await orders.saveOrder(
      customerName: 'Web Customer',
      channel: 'storefront',
      lines: const [OrderDraftLine(name: 'Item', price: 500, qty: 1)],
    );
    final remote = (await ordersDef().toRemote(db, id))!;
    remote['payment_method'] = 'cod';
    remote['updated_at'] =
        DateTime.now().add(const Duration(seconds: 1)).toUtc().toIso8601String();

    await ordersDef().upsertLocal(db, remote);

    final order = await orders.getOrder(id);
    expect(order.paymentMethod, 'cod');
  });
}
