import '../../data/local/database.dart';
import '../../data/repositories/settings_repository.dart';
import 'receipt_data.dart';

/// Assembles a printable [ReceiptData] from persisted rows + shop profile.
///
/// [paymentMethodLabel] must already be display-ready (e.g. via
/// `paymentLabel(l, sale.paymentMethod)`) — this stays free of AppLocalizations
/// so it's plain, testable data mapping. [defaultFooter] is used when the shop
/// hasn't set a custom receipt footer, so a receipt is never printed with no
/// closing line at all.
ReceiptData receiptFromSale(
  Sale sale,
  List<SaleItem> items,
  ShopProfile shop, {
  required String paymentMethodLabel,
  String? defaultFooter,
}) {
  return ReceiptData(
    shopName: shop.name,
    address: shop.address,
    phone: shop.phone,
    invoiceNo: sale.invoiceNo,
    dateTime: sale.finalizedAt,
    customerName: sale.customerName,
    customerPhone: sale.customerPhone,
    items: items
        .map((i) => ReceiptLineItem(
              name: i.nameSnapshot,
              qty: i.qty,
              unitPrice: i.priceSnapshot,
              lineTotal: i.lineTotal,
            ))
        .toList(),
    subtotal: sale.subtotal,
    discount: sale.discount,
    total: sale.total,
    paid: sale.paid,
    change: sale.changeDue,
    paymentMethod: paymentMethodLabel,
    footer: (shop.footer != null && shop.footer!.isNotEmpty)
        ? shop.footer
        : defaultFooter,
  );
}

/// Assembles a printable [ReceiptData] for a social/storefront order (not yet
/// a finalized [Sale]) — used by the order detail sheet's Print action.
ReceiptData receiptFromOrder(
  Order order,
  List<OrderItem> items,
  ShopProfile shop, {
  required String paymentMethodLabel,
  required String deliveryFeeLabel,
  String? defaultFooter,
}) {
  final total = order.itemsTotal + order.deliveryFee;
  return ReceiptData(
    shopName: shop.name,
    address: shop.address,
    phone: shop.phone,
    invoiceNo: order.orderNo,
    dateTime: order.createdAt,
    customerName: order.customerName,
    customerPhone: order.customerPhone,
    items: [
      for (final it in items)
        ReceiptLineItem(
          name: it.nameSnapshot,
          qty: it.qty,
          unitPrice: it.priceSnapshot,
          lineTotal: it.lineTotal,
        ),
      if (order.deliveryFee > 0)
        ReceiptLineItem(
          name: deliveryFeeLabel,
          qty: 1,
          unitPrice: order.deliveryFee,
          lineTotal: order.deliveryFee,
        ),
    ],
    subtotal: total,
    discount: 0,
    total: total,
    paid: order.paymentStatus == 'paid' ? total : 0,
    change: 0,
    paymentMethod: paymentMethodLabel,
    footer: (shop.footer != null && shop.footer!.isNotEmpty)
        ? shop.footer
        : defaultFooter,
  );
}
