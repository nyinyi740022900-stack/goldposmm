import 'license_status.dart';

LicensePlan _planFrom(String s) => switch (s) {
      'yearly' => LicensePlan.yearly,
      'monthly' => LicensePlan.monthly,
      _ => LicensePlan.trial,
    };

String planName(LicensePlan p) => switch (p) {
      LicensePlan.yearly => 'yearly',
      LicensePlan.monthly => 'monthly',
      LicensePlan.trial => 'trial',
    };

/// Locally cached license, refreshed from the server on activation/verify.
class CachedLicense {
  final String key;
  final String shopId;
  final LicensePlan plan;
  final DateTime expiresAt;
  final DateTime activatedAt;
  final DateTime lastVerifiedAt;
  final String deviceId;

  const CachedLicense({
    required this.key,
    required this.shopId,
    required this.plan,
    required this.expiresAt,
    required this.activatedAt,
    required this.lastVerifiedAt,
    required this.deviceId,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'shop_id': shopId,
        'plan': planName(plan),
        'expires_at': expiresAt.toIso8601String(),
        'activated_at': activatedAt.toIso8601String(),
        'last_verified_at': lastVerifiedAt.toIso8601String(),
        'device_id': deviceId,
      };

  factory CachedLicense.fromJson(Map<String, dynamic> j) => CachedLicense(
        key: j['key'] as String,
        shopId: j['shop_id'] as String,
        plan: _planFrom(j['plan'] as String? ?? 'trial'),
        expiresAt: DateTime.parse(j['expires_at'] as String),
        activatedAt: DateTime.parse(j['activated_at'] as String),
        lastVerifiedAt: DateTime.parse(
            (j['last_verified_at'] ?? j['activated_at']) as String),
        deviceId: j['device_id'] as String? ?? '',
      );

  CachedLicense copyWith({DateTime? lastVerifiedAt, DateTime? expiresAt}) =>
      CachedLicense(
        key: key,
        shopId: shopId,
        plan: plan,
        expiresAt: expiresAt ?? this.expiresAt,
        activatedAt: activatedAt,
        lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
        deviceId: deviceId,
      );
}

/// Outcome of an activation attempt.
class ActivationResult {
  final bool ok;
  final String? errorCode;
  final CachedLicense? license;

  const ActivationResult.success(this.license) : ok = true, errorCode = null;
  const ActivationResult.failure(this.errorCode) : ok = false, license = null;
}
