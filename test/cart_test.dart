import 'package:flutter_test/flutter_test.dart';
import 'package:mm_pos/data/local/database.dart';
import 'package:mm_pos/features/sell/cart.dart';

Product _product(String id, {int price = 1000}) => Product(
      id: id,
      shopId: 'shop-1',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      isDeleted: false,
      dirty: true,
      name: 'P-$id',
      costPrice: 0,
      salePrice: price,
      unit: 'pcs',
      isActive: true,
    );

void main() {
  test('addProduct without a cap keeps incrementing', () {
    final cart = CartNotifier();
    final p = _product('a');
    expect(cart.addProduct(p), isTrue);
    expect(cart.addProduct(p), isTrue);
    expect(cart.state.lines.single.qty, 2);
  });

  test('addProduct caps at maxQty (no overselling)', () {
    final cart = CartNotifier();
    final p = _product('a');
    expect(cart.addProduct(p, maxQty: 2), isTrue);
    expect(cart.addProduct(p, maxQty: 2), isTrue);
    // Third add is refused — already at available stock.
    expect(cart.addProduct(p, maxQty: 2), isFalse);
    expect(cart.state.lines.single.qty, 2);
  });

  test('addProduct with maxQty 0 (out of stock) refuses immediately', () {
    final cart = CartNotifier();
    expect(cart.addProduct(_product('a'), maxQty: 0), isFalse);
    expect(cart.state.lines, isEmpty);
  });

  test('increment respects the cap', () {
    final cart = CartNotifier();
    final p = _product('a');
    cart.addProduct(p);
    expect(cart.increment('a', maxQty: 2), isTrue); // -> 2
    expect(cart.increment('a', maxQty: 2), isFalse); // at cap
    expect(cart.state.lines.single.qty, 2);
  });
}
