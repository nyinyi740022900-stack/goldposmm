import 'package:flutter_test/flutter_test.dart';
import 'package:mm_pos/features/analytics/analytics_calculator.dart';

void main() {
  final d1 = DateTime(2026, 7, 8, 10);
  final d2 = DateTime(2026, 7, 9, 15);
  final start = DateTime(2026, 7, 8);
  final end = DateTime(2026, 7, 11); // 3-day window (8,9,10)

  // A fully-paid cash sale by default; override for credit cases.
  SaleRow sale(int total,
          {int? paid,
          String method = 'cash',
          int discount = 0,
          DateTime? at}) =>
      (
        total: total,
        paid: paid ?? total,
        paymentMethod: method,
        discount: discount,
        finalizedAt: at ?? d1,
      );

  test('aggregates revenue, sales count and discount', () {
    final s = computeAnalytics(
      sales: [
        sale(1000, discount: 100, at: d1),
        sale(500, at: d2),
      ],
      items: const [],
      productCost: const {},
      stockValue: 0,
      start: start,
      end: end,
    );
    expect(s.revenue, 1500);
    expect(s.salesCount, 2);
    expect(s.discount, 100);
  });

  test('profit = revenue - cost of goods sold', () {
    final s = computeAnalytics(
      sales: [sale(2100, at: d1)],
      items: [
        (productId: 'p1', name: 'Coke', qty: 3, lineTotal: 2100),
      ],
      productCost: {'p1': 550},
      stockValue: 0,
      start: start,
      end: end,
    );
    expect(s.cost, 1650); // 3 * 550
    expect(s.profit, 450); // 2100 - 1650
  });

  test('daily series is zero-filled across the whole range', () {
    final s = computeAnalytics(
      sales: [
        sale(300, at: d1),
        sale(700, at: d1),
      ],
      items: const [],
      productCost: const {},
      stockValue: 0,
      start: start,
      end: end,
    );
    expect(s.daily.length, 3);
    expect(s.daily[0].revenue, 1000); // both on day 1
    expect(s.daily[1].revenue, 0);
    expect(s.daily[2].revenue, 0);
  });

  test('top products ranked by revenue', () {
    final s = computeAnalytics(
      sales: const [],
      items: [
        (productId: 'a', name: 'A', qty: 1, lineTotal: 100),
        (productId: 'b', name: 'B', qty: 5, lineTotal: 900),
        (productId: 'a', name: 'A', qty: 2, lineTotal: 200),
      ],
      productCost: const {},
      stockValue: 0,
      start: start,
      end: end,
    );
    expect(s.topProducts.first.productId, 'b');
    expect(s.topProducts.first.revenue, 900);
    final a = s.topProducts.firstWhere((t) => t.productId == 'a');
    expect(a.qty, 3); // merged 1 + 2
    expect(a.revenue, 300);
  });

  test('stock value is passed through', () {
    final s = computeAnalytics(
      sales: const [],
      items: const [],
      productCost: const {},
      stockValue: 42000,
      start: start,
      end: end,
    );
    expect(s.stockValue, 42000);
  });

  test('credit metrics: outstanding = billed − paid on credit sales only', () {
    final s = computeAnalytics(
      sales: [
        sale(1000, at: d1), // cash, fully paid
        sale(5000, paid: 2000, method: 'credit', at: d1), // 3000 owed
        sale(3000, paid: 3000, method: 'credit', at: d2), // settled
      ],
      items: const [],
      productCost: const {},
      stockValue: 0,
      start: start,
      end: end,
    );
    expect(s.revenue, 9000); // full billed amount (accrual)
    expect(s.creditSales, 2);
    expect(s.creditOutstanding, 3000); // only the unpaid credit slice
    expect(s.collected, 6000); // 9000 − 3000
  });
}
