import 'package:supabase_flutter/supabase_flutter.dart';

/// Public base URL where the storefront web app is hosted. A shop's page is
/// `$storefrontBaseUrl/<slug>`.
const storefrontBaseUrl = 'https://goldposmm-shop.vercel.app';

/// The shop's own storefront config (online-only; not part of Drift/sync).
class StorefrontRow {
  final String slug;
  final String? displayName;
  final bool enabled;
  const StorefrontRow(
      {required this.slug, this.displayName, this.enabled = true});

  String get url => '$storefrontBaseUrl/$slug';
}

/// Manages the signed-in shop's storefront row. All access is RLS-scoped to the
/// caller's own `shop_id` (policy `storefront_owner`). Online-only.
class StorefrontRepository {
  StorefrontRepository(this._shopId);
  final String _shopId;
  SupabaseClient get _c => Supabase.instance.client;

  Future<StorefrontRow?> mine() async {
    final rows = await _c.from('storefronts').select() as List;
    if (rows.isEmpty) return null;
    final m = (rows.first as Map).cast<String, dynamic>();
    return StorefrontRow(
      slug: m['slug'] as String,
      displayName: m['display_name'] as String?,
      enabled: m['enabled'] as bool? ?? true,
    );
  }

  /// Publishes (creates) the storefront if absent, generating a slug from the
  /// shop name; returns the row. If one already exists, re-enables it.
  Future<StorefrontRow> publish({
    required String displayName,
    String? phone,
    String? address,
  }) async {
    final existing = await mine();
    if (existing != null) {
      await _c
          .from('storefronts')
          .update({'enabled': true}).eq('shop_id', _shopId);
      return StorefrontRow(
          slug: existing.slug,
          displayName: existing.displayName,
          enabled: true);
    }
    final slug =
        await _c.rpc('gen_storefront_slug', params: {'p_name': displayName})
            as String;
    await _c.from('storefronts').insert({
      'shop_id': _shopId,
      'slug': slug,
      'display_name': displayName,
      'phone': phone,
      'address': address,
      'enabled': true,
    });
    return StorefrontRow(slug: slug, displayName: displayName, enabled: true);
  }

  Future<void> setEnabled(bool enabled) async {
    await _c
        .from('storefronts')
        .update({'enabled': enabled}).eq('shop_id', _shopId);
  }
}
