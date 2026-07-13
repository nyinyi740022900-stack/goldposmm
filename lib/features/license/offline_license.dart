import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'license_model.dart';
import 'license_status.dart';

/// Verifies **offline** signed license tokens — no internet required.
///
/// A token is `MMPOS1.<base64url(payload)>.<base64url(signature)>`. The admin
/// signs `"MMPOS1." + base64url(payload)` with an Ed25519 private key (kept as
/// a Supabase secret); the app verifies it against the matching public key
/// baked in below. The payload carries shop/plan/expiry and an optional device
/// binding, so a shop with no connectivity can activate + renew by pasting a
/// code the admin sends them.
class OfflineLicense {
  OfflineLicense._();

  /// Ed25519 public key (hex). Safe to ship — it only verifies signatures.
  static const publicKeyHex =
      'e31d30dd9e16dc59c8ce0b7f98cce9b9cbc0e1a9bd8571bfaf6d19a5f63e8754';

  static const prefix = 'MMPOS1.';

  static bool looksLikeToken(String s) => s.trim().startsWith(prefix);

  /// Verifies [raw] and returns a [CachedLicense] on success, or throws
  /// [OfflineLicenseException]. [publicKeyHex] is overridable for tests.
  static Future<CachedLicense> verify(
    String raw,
    String deviceId, {
    String? publicKeyHex,
  }) async {
    final token = raw.trim();
    final parts = token.split('.');
    // MMPOS1 . payload . signature
    if (parts.length != 3 || '${parts[0]}.' != prefix) {
      throw const OfflineLicenseException('invalid_format');
    }
    final payloadB64 = parts[1];
    final sigBytes = base64Url.decode(_pad(parts[2]));
    final signedMessage = utf8.encode('$prefix$payloadB64');
    final pubBytes = _hex(publicKeyHex ?? OfflineLicense.publicKeyHex);

    final ok = await Ed25519().verify(
      signedMessage,
      signature: Signature(
        sigBytes,
        publicKey: SimplePublicKey(pubBytes, type: KeyPairType.ed25519),
      ),
    );
    if (!ok) throw const OfflineLicenseException('bad_signature');

    final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(utf8.decode(base64Url.decode(_pad(payloadB64))))
          as Map<String, dynamic>;
    } catch (_) {
      throw const OfflineLicenseException('invalid_payload');
    }

    final exp = payload['exp'];
    if (exp is! int) throw const OfflineLicenseException('invalid_payload');
    final expiresAt =
        DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true).toLocal();

    final bound = (payload['device_id'] as String?)?.trim();
    if (bound != null && bound.isNotEmpty && bound != deviceId) {
      throw const OfflineLicenseException('device_mismatch');
    }

    return CachedLicense(
      key: token,
      shopId: (payload['shop_id'] as String?) ?? 'offline',
      plan: _plan(payload['plan'] as String?),
      expiresAt: expiresAt,
      activatedAt: DateTime.now(),
      lastVerifiedAt: DateTime.now(),
      deviceId: deviceId,
    );
  }

  static LicensePlan _plan(String? s) => switch (s) {
        'yearly' => LicensePlan.yearly,
        'monthly' => LicensePlan.monthly,
        _ => LicensePlan.trial,
      };

  static String _pad(String s) =>
      s.length % 4 == 0 ? s : s.padRight(s.length + (4 - s.length % 4), '=');

  static List<int> _hex(String h) => [
        for (var i = 0; i < h.length; i += 2)
          int.parse(h.substring(i, i + 2), radix: 16),
      ];
}

class OfflineLicenseException implements Exception {
  final String code;
  const OfflineLicenseException(this.code);
  @override
  String toString() => 'OfflineLicenseException($code)';
}
