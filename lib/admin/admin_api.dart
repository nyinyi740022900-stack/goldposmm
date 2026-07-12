import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin client over the `admin` Edge Function. Every call carries the current
/// admin session's JWT (added automatically by `functions.invoke`); the
/// function verifies the `role=admin` claim and uses the service role
/// server-side. The web app never holds the service key.
class AdminApi {
  SupabaseClient get _c => Supabase.instance.client;

  bool get isSignedIn => _c.auth.currentSession != null;

  bool get isAdmin =>
      (_c.auth.currentUser?.appMetadata['role']) == 'admin';

  Future<void> signIn(String email, String password) =>
      _c.auth.signInWithPassword(email: email, password: password);

  Future<void> signOut() => _c.auth.signOut();

  Future<List<Map<String, dynamic>>> _rows(String action) async {
    final res = await _c.functions.invoke('admin', body: {'action': action});
    _throwIfError(res);
    return (((res.data as Map)['rows'] as List?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  Future<List<Map<String, dynamic>>> listLicenses() => _rows('list_licenses');
  Future<List<Map<String, dynamic>>> listPayments() => _rows('list_payments');

  Future<String> createLicense({
    required String shopId,
    required String plan,
    required int months,
  }) async {
    final res = await _c.functions.invoke('admin', body: {
      'action': 'create_license',
      'shop_id': shopId,
      'plan': plan,
      'months': months,
    });
    _throwIfError(res);
    return (res.data as Map)['key'] as String;
  }

  Future<String> renewLicense({
    required String key,
    required int months,
    String? paymentId,
  }) async {
    final body = <String, dynamic>{
      'action': 'renew_license',
      'key': key,
      'months': months,
    };
    if (paymentId != null) body['payment_id'] = paymentId;
    final res = await _c.functions.invoke('admin', body: body);
    _throwIfError(res);
    return '${(res.data as Map)['expires_at']}';
  }

  void _throwIfError(FunctionResponse res) {
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw Exception('${data['error']}${data['detail'] != null ? ': ${data['detail']}' : ''}');
    }
    if (res.status >= 400) {
      throw Exception('Request failed (${res.status})');
    }
  }
}
