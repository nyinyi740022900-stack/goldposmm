import 'package:supabase_flutter/supabase_flutter.dart';

/// A shop this user referred (as seen by the referrer — RLS scopes it).
class ReferredShop {
  final String shopId;
  final bool active;
  final DateTime? createdAt;
  const ReferredShop({
    required this.shopId,
    this.active = true,
    this.createdAt,
  });
}

/// Earnings snapshot for the current shop, from `my_referral_balance()`.
class ReferralSummary {
  final String? code; // this shop's own shareable code
  final int earned; // lifetime commission earned (Ks)
  final int redeemed; // already turned into license days (Ks)
  final int balance; // earned - redeemed (Ks)
  final int activeReferrals;

  const ReferralSummary({
    this.code,
    this.earned = 0,
    this.redeemed = 0,
    this.balance = 0,
    this.activeReferrals = 0,
  });

  static const empty = ReferralSummary();
}

/// Reads referral state for the signed-in shop. All reads are RLS-scoped to the
/// caller's own `shop_id`, and redemption goes through a SECURITY DEFINER RPC
/// that only ever touches the caller's own balance.
class ReferralRepository {
  SupabaseClient get _c => Supabase.instance.client;

  Future<String?> myCode() async {
    final rows =
        await _c.from('licenses').select('referral_code').limit(1) as List;
    if (rows.isEmpty) return null;
    return (rows.first as Map)['referral_code'] as String?;
  }

  Future<ReferralSummary> summary() async {
    final code = await myCode();
    final res = await _c.rpc('my_referral_balance');
    final m = (res as Map).cast<String, dynamic>();
    return ReferralSummary(
      code: code,
      earned: (m['earned'] as num?)?.toInt() ?? 0,
      redeemed: (m['redeemed'] as num?)?.toInt() ?? 0,
      balance: (m['balance'] as num?)?.toInt() ?? 0,
      activeReferrals: (m['active_referrals'] as num?)?.toInt() ?? 0,
    );
  }

  Future<List<ReferredShop>> referredShops() async {
    final rows = await _c
        .from('referrals')
        .select('referred_shop_id, is_active, created_at')
        .order('created_at', ascending: false) as List;
    return rows.map((r) {
      final m = r as Map;
      return ReferredShop(
        shopId: m['referred_shop_id'] as String,
        active: m['is_active'] as bool? ?? true,
        createdAt: m['created_at'] != null
            ? DateTime.tryParse(m['created_at'] as String)
            : null,
      );
    }).toList();
  }

  /// Converts the whole-month portion of the balance into license days on the
  /// caller's own license. Returns the number of months added (0 if the balance
  /// isn't yet one month's price).
  Future<int> redeem() async {
    final res = await _c.rpc('redeem_referral_balance');
    final m = (res as Map).cast<String, dynamic>();
    return (m['months'] as num?)?.toInt() ?? 0;
  }
}
