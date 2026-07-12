import '../../data/local/database.dart';
import '../../data/repositories/settings_repository.dart';
import 'receipt_data.dart';

/// Assembles a printable [ReceiptData] from persisted rows + shop profile.
ReceiptData receiptFromSale(
  Sale sale,
  List<SaleItem> items,
  ShopProfile shop,
) {
  return ReceiptData(
    shopName: shop.name,
    address: shop.address,
    phone: shop.phone,
    invoiceNo: sale.invoiceNo,
    dateTime: sale.finalizedAt,
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
    paymentMethod: sale.paymentMethod,
    footer: shop.footer,
  );
}
