import '../data/local/database.dart';

/// Read model combining a product with its current stock quantity.
class ProductWithStock {
  final Product product;
  final int quantity;
  final int reorderLevel;

  const ProductWithStock({
    required this.product,
    required this.quantity,
    required this.reorderLevel,
  });

  bool get isLowStock => reorderLevel > 0 && quantity <= reorderLevel;
}
