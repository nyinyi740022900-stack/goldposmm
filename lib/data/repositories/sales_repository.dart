import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../features/sell/cart.dart';
import '../local/database.dart';

/// Result of finalizing a sale.
class SaleResult {
  final String saleId;
  final String invoiceNo;
  const SaleResult(this.saleId, this.invoiceNo);
}

/// Handles checkout. A sale is written **append-only** together with its
/// items, payment, and stock movements — all inside one transaction so the
/// books can never end up half-written. Every row is queued to the Outbox.
class SalesRepository {
  SalesRepository(this._db, this._shopId);

  final AppDatabase _db;
  final String _shopId;
  static const _uuid = Uuid();

  Stream<List<Sale>> watchSales() {
    return (_db.select(_db.sales)
          ..where((s) => s.shopId.equals(_shopId) & s.isDeleted.equals(false))
          ..orderBy([(s) => OrderingTerm.desc(s.finalizedAt)]))
        .watch();
  }

  Future<Sale> getSale(String saleId) {
    return (_db.select(_db.sales)..where((s) => s.id.equals(saleId)))
        .getSingle();
  }

  Future<List<SaleItem>> saleItems(String saleId) {
    return (_db.select(_db.saleItems)
          ..where((i) => i.saleId.equals(saleId))
          ..orderBy([(i) => OrderingTerm(expression: i.createdAt)]))
        .get();
  }

  /// Finalizes [cart] and returns the new invoice reference.
  Future<SaleResult> finalizeSale({
    required CartState cart,
    required String paymentMethod,
    required int paid,
    String? customerName,
    String? customerPhone,
    String? staffId,
    bool trackStock = true,
  }) async {
    if (cart.isEmpty) {
      throw StateError('Cannot finalize an empty cart');
    }

    final saleId = _uuid.v4();
    final now = DateTime.now();
    final subtotal = cart.subtotal.kyat;
    final total = cart.total.kyat;
    final change = paid > total ? paid - total : 0;

    await _db.transaction(() async {
      final invoiceNo = await _nextInvoiceNo(now);

      final sale = SalesCompanion.insert(
        id: saleId,
        shopId: _shopId,
        invoiceNo: invoiceNo,
        staffId: Value(staffId),
        subtotal: Value(subtotal),
        discount: Value(cart.discount),
        total: Value(total),
        paid: Value(paid),
        changeDue: Value(change),
        paymentMethod: Value(paymentMethod),
        customerName: Value(customerName),
        customerPhone: Value(customerPhone),
        finalizedAt: Value(now),
        updatedAt: Value(now),
      );
      await _db.into(_db.sales).insert(sale);
      await _enqueue('sales', saleId, jsonEncode(
          (await _one(_db.sales, (t) => t.id.equals(saleId))).toJson()));

      for (final line in cart.lines) {
        final itemId = _uuid.v4();
        await _db.into(_db.saleItems).insert(SaleItemsCompanion.insert(
              id: itemId,
              shopId: _shopId,
              saleId: saleId,
              productId: line.product.id,
              nameSnapshot: line.product.name,
              priceSnapshot: line.unitPrice.kyat,
              qty: line.qty,
              lineTotal: line.lineTotal.kyat,
              updatedAt: Value(now),
            ));
        await _enqueue('sale_items', itemId, jsonEncode(
            (await _one(_db.saleItems, (t) => t.id.equals(itemId))).toJson()));

        // Stock movement (ledger) + decrement the cached level. Skipped for
        // invoice-only shops that don't track inventory.
        if (trackStock) {
          await _recordStockOut(line.product.id, line.qty, saleId, now);
        }
      }

      // Tender actually collected. For cash/digital this equals the total
      // (change is handled separately); for a credit sale it may be a partial
      // down-payment (or 0), leaving total − paid owed by the customer.
      final settled = paid > total ? total : paid;
      final payId = _uuid.v4();
      await _db.into(_db.payments).insert(PaymentsCompanion.insert(
            id: payId,
            shopId: _shopId,
            saleId: saleId,
            method: paymentMethod,
            amount: settled,
            updatedAt: Value(now),
          ));
      await _enqueue('payments', payId, jsonEncode(
          (await _one(_db.payments, (t) => t.id.equals(payId))).toJson()));
    });

    // Re-read invoice number for the return value.
    final saved = await _one(_db.sales, (t) => t.id.equals(saleId));
    return SaleResult(saleId, saved.invoiceNo);
  }

  // ---- internals ---------------------------------------------------------

  Future<void> _recordStockOut(
      String productId, int qty, String saleId, DateTime now) async {
    final moveId = _uuid.v4();
    await _db.into(_db.stockMovements).insert(StockMovementsCompanion.insert(
          id: moveId,
          shopId: _shopId,
          productId: productId,
          type: 'sale',
          qtyDelta: -qty,
          refId: Value(saleId),
          updatedAt: Value(now),
        ));
    await _enqueue('stock_movements', moveId, jsonEncode(
        (await _one(_db.stockMovements, (t) => t.id.equals(moveId))).toJson()));

    // Decrement the denormalized stock level if present.
    final level = await (_db.select(_db.stockLevels)
          ..where((s) => s.productId.equals(productId)))
        .getSingleOrNull();
    if (level != null) {
      await (_db.update(_db.stockLevels)..where((s) => s.id.equals(level.id)))
          .write(StockLevelsCompanion(
        quantity: Value(level.quantity - qty),
        updatedAt: Value(now),
        dirty: const Value(true),
      ));
      await _enqueue('stock_levels', level.id, jsonEncode(
          (await _one(_db.stockLevels, (t) => t.id.equals(level.id))).toJson()));
    }
  }

  /// Per-shop, per-day sequential invoice number: `INV-yyyyMMdd-NNN`.
  Future<String> _nextInvoiceNo(DateTime now) async {
    final dayStart = DateTime(now.year, now.month, now.day);
    final todays = await (_db.select(_db.sales)
          ..where((s) =>
              s.shopId.equals(_shopId) &
              s.finalizedAt.isBiggerOrEqualValue(dayStart)))
        .get();
    final seq = (todays.length + 1).toString().padLeft(3, '0');
    return 'INV-${DateFormat('yyyyMMdd').format(now)}-$seq';
  }

  Future<D> _one<T extends Table, D>(
    TableInfo<T, D> table,
    Expression<bool> Function(T) filter,
  ) {
    return (_db.select(table)..where(filter)).getSingle();
  }

  Future<void> _enqueue(String table, String rowId, String payload) {
    return _db.into(_db.outbox).insert(OutboxCompanion.insert(
          entityTable: table,
          rowId: rowId,
          op: 'upsert',
          payload: payload,
        ));
  }
}
