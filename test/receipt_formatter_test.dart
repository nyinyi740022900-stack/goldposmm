import 'package:flutter_test/flutter_test.dart';
import 'package:mm_pos/features/invoices/receipt_data.dart';
import 'package:mm_pos/features/invoices/receipt_formatter.dart';

const _labels = ReceiptLabels(
  invoice: 'Invoice',
  date: 'Date',
  cashier: 'Cashier',
  subtotal: 'Subtotal',
  discount: 'Discount',
  total: 'Total',
  payment: 'Payment',
  paid: 'Paid',
  change: 'Change',
);

ReceiptData _sample({int discount = 0, String? longName}) => ReceiptData(
      shopName: 'Aung Minimart',
      address: 'Yangon',
      invoiceNo: 'INV-20260710-001',
      dateTime: DateTime(2026, 7, 10, 14, 30),
      items: [
        ReceiptLineItem(
            name: longName ?? 'Coca-Cola',
            qty: 2,
            unitPrice: 700,
            lineTotal: 1400),
      ],
      subtotal: 1400,
      discount: discount,
      total: 1400 - discount,
      paid: 2000,
      change: 2000 - (1400 - discount),
      paymentMethod: 'Cash',
      footer: 'Thank you!',
    );

void main() {
  group('ReceiptFormatter', () {
    test('every line fits within the 58mm width (32 chars)', () {
      final lines = ReceiptFormatter(paper: PaperSize.mm58, labels: _labels)
          .format(_sample());
      for (final line in lines) {
        expect(line.length, lessThanOrEqualTo(32),
            reason: 'line too wide: "$line"');
      }
    });

    test('divider spans the full paper width', () {
      final lines = ReceiptFormatter(paper: PaperSize.mm80, labels: _labels)
          .format(_sample());
      expect(lines.any((l) => l == '-' * 48), isTrue);
    });

    test('two-column rows are padded so the amount is right-aligned', () {
      final lines = ReceiptFormatter(paper: PaperSize.mm58, labels: _labels)
          .format(_sample());
      final totalLine = lines.firstWhere((l) => l.startsWith('Total'));
      expect(totalLine.length, 32);
      expect(totalLine.trimRight().endsWith('Ks'), isTrue);
    });

    test('discount line only appears when there is a discount', () {
      final none = ReceiptFormatter(paper: PaperSize.mm58, labels: _labels)
          .format(_sample());
      expect(none.any((l) => l.startsWith('Discount')), isFalse);

      final withDisc = ReceiptFormatter(paper: PaperSize.mm58, labels: _labels)
          .format(_sample(discount: 200));
      expect(withDisc.any((l) => l.startsWith('Discount')), isTrue);
    });

    test('long product names wrap without exceeding width', () {
      final lines = ReceiptFormatter(paper: PaperSize.mm58, labels: _labels)
          .format(_sample(
              longName:
                  'Super Extra Large Family Size Instant Noodles Chicken'));
      for (final line in lines) {
        expect(line.length, lessThanOrEqualTo(32));
      }
    });
  });
}
