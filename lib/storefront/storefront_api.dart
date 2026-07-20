import 'package:supabase_flutter/supabase_flutter.dart';

/// A product shown on the public storefront.
class StoreProduct {
  final String id;
  final String name;
  final int price;
  final String unit;
  const StoreProduct(this.id, this.name, this.price, this.unit);
}

/// Public shop info + payment numbers shown to customers.
class StoreInfo {
  final String? displayName;
  final String? phone;
  final String? address;
  final String? payKpay;
  final String? payWave;
  const StoreInfo(
      {this.displayName, this.phone, this.address, this.payKpay, this.payWave});
}

class Catalog {
  final StoreInfo info;
  final List<StoreProduct> products;
  const Catalog(this.info, this.products);
}

/// One line the customer wants to order.
class OrderLine {
  final String productId;
  final String name;
  final int price;
  final int qty;
  const OrderLine(this.productId, this.name, this.price, this.qty);
}

/// Talks to the `storefront` Edge Function. The browser only ever holds the
/// anon key; the function reads/writes across RLS with the service role.
class StorefrontApi {
  SupabaseClient get _c => Supabase.instance.client;

  Future<Catalog> fetchCatalog(String slug) async {
    final res = await _c.functions
        .invoke('storefront', body: {'action': 'catalog', 'slug': slug});
    if (res.status != 200) {
      throw Exception(res.data is Map ? res.data['error'] : 'error');
    }
    final data = (res.data as Map).cast<String, dynamic>();
    final s = (data['storefront'] as Map).cast<String, dynamic>();
    final products = (data['products'] as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .map((m) => StoreProduct(
              m['id'] as String,
              m['name'] as String,
              (m['sale_price'] as num?)?.toInt() ?? 0,
              (m['unit'] as String?) ?? 'pcs',
            ))
        .toList();
    return Catalog(
      StoreInfo(
        displayName: s['display_name'] as String?,
        phone: s['phone'] as String?,
        address: s['address'] as String?,
        payKpay: s['pay_kpay'] as String?,
        payWave: s['pay_wave'] as String?,
      ),
      products,
    );
  }

  /// Submits a guest order. Returns the order number.
  Future<String> submitOrder({
    required String slug,
    required String customerName,
    String? phone,
    String? address,
    String? note,
    required List<OrderLine> lines,
  }) async {
    final res = await _c.functions.invoke('storefront', body: {
      'action': 'submit_order',
      'slug': slug,
      'customer_name': customerName,
      'phone': phone,
      'address': address,
      'note': note,
      'lines': [
        for (final l in lines)
          {
            'product_id': l.productId,
            'name': l.name,
            'price': l.price,
            'qty': l.qty,
          }
      ],
    });
    if (res.status != 200 || (res.data is Map && res.data['ok'] != true)) {
      throw Exception(res.data is Map ? res.data['error'] : 'error');
    }
    return (res.data as Map)['order_no'] as String;
  }
}
