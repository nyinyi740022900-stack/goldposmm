import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_pos/data/local/database.dart';
import 'package:mm_pos/data/repositories/inventory_repository.dart';
import 'package:mm_pos/data/repositories/sales_repository.dart';
import 'package:mm_pos/features/credit/credit_repository.dart';
import 'package:mm_pos/features/sell/cart.dart';

void main() {
  group('CreditRepository.aggregate (pure)', () {
    Sale creditSale(String name, int total, int paid) => Sale(
          id: 'sale-$name-$total-$paid',
          shopId: 'shop-1',
          invoiceNo: 'INV-1',
          subtotal: total,
          discount: 0,
          tax: 0,
          total: total,
          paid: paid,
          changeDue: 0,
          paymentMethod: 'credit',
          customerName: name,
          finalizedAt: DateTime(2026, 7, 1),
          createdAt: DateTime(2026, 7, 1),
          updatedAt: DateTime(2026, 7, 1),
          isDeleted: false,
          dirty: false,
        );

    CreditPayment repay(String name, int amount) => CreditPayment(
          id: 'pay-$name-$amount',
          shopId: 'shop-1',
          customerName: name,
          method: 'cash',
          amount: amount,
          createdAt: DateTime(2026, 7, 2),
          updatedAt: DateTime(2026, 7, 2),
          isDeleted: false,
          dirty: false,
        );

    test('outstanding = billed - down-payment - repayments', () {
      final result = CreditRepository.aggregate(
        [creditSale('Aung', 10000, 2000)],
        [repay('Aung', 3000)],
      );
      expect(result, hasLength(1));
      expect(result.single.name, 'Aung');
      expect(result.single.outstanding, 5000); // 10000 - 2000 - 3000
      expect(result.single.openInvoices, 1);
    });

    test('fully-settled customers are dropped', () {
      final result = CreditRepository.aggregate(
        [creditSale('Bo', 5000, 0)],
        [repay('Bo', 5000)],
      );
      expect(result, isEmpty);
    });

    test('multiple invoices for one customer sum up', () {
      final result = CreditRepository.aggregate(
        [creditSale('Cho', 3000, 0), creditSale('Cho', 2000, 500)],
        const [],
      );
      expect(result.single.outstanding, 4500); // 3000 + 1500
      expect(result.single.openInvoices, 2);
    });

    test('customers sorted by outstanding, largest first', () {
      final result = CreditRepository.aggregate(
        [creditSale('Small', 1000, 0), creditSale('Big', 9000, 0)],
        const [],
      );
      expect(result.map((c) => c.name).toList(), ['Big', 'Small']);
    });

    test('unnamed credit sales are ignored', () {
      final result = CreditRepository.aggregate(
        [creditSale('', 5000, 0)],
        const [],
      );
      expect(result, isEmpty);
    });
  });

  group('CreditRepository with DB', () {
    late AppDatabase db;
    late CreditRepository credit;
    late SalesRepository sales;
    late InventoryRepository inventory;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      credit = CreditRepository(db, 'shop-1');
      sales = SalesRepository(db, 'shop-1');
      inventory = InventoryRepository(db, 'shop-1');
    });

    tearDown(() async => db.close());

    test('a credit sale records partial paid and shows as outstanding',
        () async {
      final id = await inventory.upsertProduct(
          name: 'Rice bag', salePrice: 10000, quantity: 5);
      final product = (await inventory.watchProducts().first)
          .firstWhere((p) => p.product.id == id)
          .product;

      await sales.finalizeSale(
        cart: CartState(lines: [CartLine(product: product, qty: 1)]),
        paymentMethod: 'credit',
        paid: 4000,
        customerName: 'Daw Mya',
      );

      final sale = await sales.watchSales().first;
      expect(sale.single.paymentMethod, 'credit');
      expect(sale.single.paid, 4000);
      // Payment tender recorded is the actual down-payment, not the total.
      final payment = (await db.select(db.payments).get()).single;
      expect(payment.amount, 4000);

      final customers = CreditRepository.aggregate(
        await credit.watchCreditSales().first,
        await credit.watchRepayments().first,
      );
      expect(customers.single.name, 'Daw Mya');
      expect(customers.single.outstanding, 6000);
    });

    test('recordRepayment writes row + enqueues outbox', () async {
      await credit.recordRepayment(
          customerName: 'Daw Mya', amount: 6000, method: 'kbzpay');

      final rows = await db.select(db.creditPayments).get();
      expect(rows.single.customerName, 'Daw Mya');
      expect(rows.single.amount, 6000);
      expect(rows.single.method, 'kbzpay');

      final outbox =
          (await db.select(db.outbox).get()).map((o) => o.entityTable).toSet();
      expect(outbox, contains('credit_payments'));
    });
  });
}
