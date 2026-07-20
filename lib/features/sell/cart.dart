import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/local/database.dart';

/// One line in the current sale.
class CartLine {
  final Product product;
  final int qty;

  const CartLine({required this.product, required this.qty});

  Money get unitPrice => Money(product.salePrice);
  Money get lineTotal => unitPrice * qty;

  CartLine copyWith({int? qty}) =>
      CartLine(product: product, qty: qty ?? this.qty);
}

/// The in-progress sale: line items + an order-level discount (in kyat).
class CartState {
  final List<CartLine> lines;
  final int discount;

  const CartState({this.lines = const [], this.discount = 0});

  bool get isEmpty => lines.isEmpty;
  int get itemCount => lines.fold(0, (s, l) => s + l.qty);

  Money get subtotal =>
      lines.fold(Money.zero, (s, l) => s + l.lineTotal);
  Money get total {
    final t = subtotal - Money(discount);
    return t.isNegative ? Money.zero : t;
  }

  CartState copyWith({List<CartLine>? lines, int? discount}) =>
      CartState(lines: lines ?? this.lines, discount: discount ?? this.discount);
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  /// Adds one of [product] to the cart. When [maxQty] is given (the available
  /// stock), the line is capped at it — prevents overselling. Returns `false`
  /// if the line is already at the cap (nothing added), so the UI can warn.
  bool addProduct(Product product, {int? maxQty}) {
    final lines = [...state.lines];
    final idx = lines.indexWhere((l) => l.product.id == product.id);
    final current = idx >= 0 ? lines[idx].qty : 0;
    if (maxQty != null && current >= maxQty) return false;
    if (idx >= 0) {
      lines[idx] = lines[idx].copyWith(qty: current + 1);
    } else {
      lines.add(CartLine(product: product, qty: 1));
    }
    state = state.copyWith(lines: lines);
    return true;
  }

  void setQty(String productId, int qty) {
    if (qty <= 0) {
      removeProduct(productId);
      return;
    }
    final lines = state.lines
        .map((l) => l.product.id == productId ? l.copyWith(qty: qty) : l)
        .toList();
    state = state.copyWith(lines: lines);
  }

  /// Increments a line, capped at [maxQty] (available stock) when given.
  /// Returns `false` if already at the cap.
  bool increment(String productId, {int? maxQty}) {
    final line = state.lines.firstWhereOrNull((l) => l.product.id == productId);
    if (line == null) return false;
    if (maxQty != null && line.qty >= maxQty) return false;
    setQty(productId, line.qty + 1);
    return true;
  }

  void decrement(String productId) {
    final line = state.lines.firstWhereOrNull((l) => l.product.id == productId);
    if (line != null) setQty(productId, line.qty - 1);
  }

  void removeProduct(String productId) {
    state = state.copyWith(
      lines: state.lines.where((l) => l.product.id != productId).toList(),
    );
  }

  void setDiscount(int discount) =>
      state = state.copyWith(discount: discount < 0 ? 0 : discount);

  void clear() => state = const CartState();
}

final cartProvider =
    StateNotifierProvider<CartNotifier, CartState>((ref) => CartNotifier());
