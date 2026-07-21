import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/local/database.dart';
import '../../l10n/app_localizations.dart';
import '../invoices/receipt_data.dart';
import '../invoices/receipt_formatter.dart';
import '../printing/printing_providers.dart';
import '../printing/receipt_raster.dart';

/// Builds an invoice image for an order and opens the share sheet so the shop
/// can save it (Photos/Files) or send it to the customer (Viber/Messenger).
///
/// Works for any order (social or storefront) — an order isn't a finalized
/// sale yet, so this is a standalone invoice rendered from the order + its
/// items, not from the append-only sales ledger.
Future<void> shareOrderInvoice(
  BuildContext context,
  WidgetRef ref,
  Order order,
  List<OrderItem> items,
) async {
  final l = AppLocalizations.of(context);
  final profile = await ref.read(shopProfileProvider.future);
  final total = order.itemsTotal + order.deliveryFee;

  final data = ReceiptData(
    shopName: profile.name,
    address: profile.address,
    phone: profile.phone,
    invoiceNo: order.orderNo,
    dateTime: order.createdAt,
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
          name: l.orderDeliveryFee,
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
    paymentMethod: order.customerName,
    footer: profile.footer,
  );

  final lines =
      ReceiptFormatter(paper: PaperSize.mm80, labels: receiptLabels(l))
          .format(data);
  final image = await renderReceiptImage(lines, PaperSize.mm80);
  final png = img.encodePng(image);

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/invoice-${order.orderNo}.png');
  await file.writeAsBytes(png);

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'image/png')],
      subject: 'Invoice ${order.orderNo}',
    ),
  );
}
