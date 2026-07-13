import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/database.dart';

/// A customer's outstanding credit, aggregated from their credit sales minus
/// repayments. Customers are keyed by [name] (free-text, matching
/// `Sales.customerName`).
class CreditCustomer {
  final String name;
  final String? phone;
  final int billed; // Σ total of credit sales
  final int paid; // Σ down-payments on those sales + Σ repayments
  final int openInvoices;

  const CreditCustomer({
    required this.name,
    this.phone,
    required this.billed,
    required this.paid,
    required this.openInvoices,
  });

  int get outstanding {
    final o = billed - paid;
    return o < 0 ? 0 : o;
  }
}

/// Reads/writes the credit book. Credit sales themselves live in [Sales]
/// (`paymentMethod = 'credit'`); this repository adds repayments and the
/// per-customer aggregation.
class CreditRepository {
  CreditRepository(this._db, this._shopId);

  final AppDatabase _db;
  final String _shopId;
  static const _uuid = Uuid();

  /// Sales that carry an outstanding balance — any sale where less than the
  /// total was paid, regardless of the tendered method. Newest first.
  Stream<List<Sale>> watchCreditSales() {
    return (_db.select(_db.sales)
          ..where((s) =>
              s.shopId.equals(_shopId) &
              s.isDeleted.equals(false) &
              s.paid.isSmallerThan(s.total))
          ..orderBy([(s) => OrderingTerm.desc(s.finalizedAt)]))
        .watch();
  }

  Stream<List<CreditPayment>> watchRepayments() {
    return (_db.select(_db.creditPayments)
          ..where((p) => p.shopId.equals(_shopId) & p.isDeleted.equals(false))
          ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
        .watch();
  }

  /// Folds credit sales + repayments into a per-customer balance. Only
  /// customers who still owe money are returned, largest balance first.
  static List<CreditCustomer> aggregate(
    List<Sale> creditSales,
    List<CreditPayment> repayments,
  ) {
    final billed = <String, int>{};
    final paid = <String, int>{};
    final openInvoices = <String, int>{};
    final phone = <String, String>{};

    for (final s in creditSales) {
      final name = (s.customerName ?? '').trim();
      if (name.isEmpty) continue;
      billed[name] = (billed[name] ?? 0) + s.total;
      paid[name] = (paid[name] ?? 0) + s.paid;
      if (s.total - s.paid > 0) {
        openInvoices[name] = (openInvoices[name] ?? 0) + 1;
      }
      final ph = (s.customerPhone ?? '').trim();
      if (ph.isNotEmpty) phone[name] = ph;
    }
    for (final r in repayments) {
      final name = r.customerName.trim();
      if (name.isEmpty) continue;
      paid[name] = (paid[name] ?? 0) + r.amount;
    }

    final customers = <CreditCustomer>[];
    for (final name in billed.keys) {
      final c = CreditCustomer(
        name: name,
        phone: phone[name],
        billed: billed[name] ?? 0,
        paid: paid[name] ?? 0,
        openInvoices: openInvoices[name] ?? 0,
      );
      if (c.outstanding > 0) customers.add(c);
    }
    customers.sort((a, b) => b.outstanding.compareTo(a.outstanding));
    return customers;
  }

  /// Allocates each customer's repayments across their credit invoices,
  /// **oldest first**, and returns the remaining owed per sale id. Once an
  /// invoice is fully covered by repayments its owed drops to 0 (so it
  /// disappears from the credit list even though the sale row is append-only).
  static Map<String, int> owedBySale(
    List<Sale> creditSales,
    List<CreditPayment> repayments,
  ) {
    final byCustomer = <String, List<Sale>>{};
    for (final s in creditSales) {
      byCustomer.putIfAbsent((s.customerName ?? '').trim(), () => []).add(s);
    }
    final pool = <String, int>{};
    for (final r in repayments) {
      final n = r.customerName.trim();
      pool[n] = (pool[n] ?? 0) + r.amount;
    }
    final result = <String, int>{};
    byCustomer.forEach((name, sales) {
      final sorted = [...sales]
        ..sort((a, b) => a.finalizedAt.compareTo(b.finalizedAt));
      var remaining = pool[name] ?? 0;
      for (final s in sorted) {
        final owed = s.total - s.paid;
        if (owed <= 0) {
          result[s.id] = 0;
          continue;
        }
        final applied = remaining >= owed ? owed : remaining;
        remaining -= applied;
        result[s.id] = owed - applied;
      }
    });
    return result;
  }

  /// Records a repayment against a customer's outstanding credit and queues it
  /// for sync.
  Future<void> recordRepayment({
    required String customerName,
    required int amount,
    String method = 'cash',
    String? note,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await _db.into(_db.creditPayments).insert(CreditPaymentsCompanion.insert(
          id: id,
          shopId: _shopId,
          customerName: customerName.trim(),
          amount: amount,
          method: Value(method),
          note: Value(note),
          updatedAt: Value(now),
        ));
    final row = await (_db.select(_db.creditPayments)
          ..where((t) => t.id.equals(id)))
        .getSingle();
    await _db.into(_db.outbox).insert(OutboxCompanion.insert(
          entityTable: 'credit_payments',
          rowId: id,
          op: 'upsert',
          payload: jsonEncode(row.toJson()),
        ));
  }
}
