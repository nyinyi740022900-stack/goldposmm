import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import '../../data/repositories/settings_repository.dart';
import 'license_model.dart';
import 'license_status.dart';

/// Owns license activation and local caching.
///
/// Online activation calls the `activate` Edge Function (which validates the
/// key, binds the device, and sets the JWT `shop_id` claim). When no backend
/// is configured it falls back to a local trial so development and offline
/// demos keep working.
class LicenseRepository {
  LicenseRepository(this._settings);

  final SettingsRepository _settings;

  Future<CachedLicense?> current() async {
    final raw = await _settings.licenseJson();
    if (raw == null) return null;
    try {
      return CachedLicense.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<CachedLicense?> _save(CachedLicense lic) async {
    await _settings.setLicenseJson(jsonEncode(lic.toJson()));
    return lic;
  }

  Future<ActivationResult> activate(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return const ActivationResult.failure('empty_key');
    final deviceId = await _settings.deviceId();

    if (!Env.hasBackend) {
      return ActivationResult.success(await _localTrial(trimmed, deviceId));
    }

    try {
      final res = await Supabase.instance.client.functions.invoke(
        'activate',
        body: {'key': trimmed, 'device_id': deviceId},
      );
      final data = res.data as Map<String, dynamic>;
      if (data['ok'] != true) {
        return ActivationResult.failure(
            (data['error'] as String?) ?? 'activation_failed');
      }
      final now = DateTime.now();
      final lic = CachedLicense(
        key: trimmed,
        shopId: data['shop_id'] as String,
        plan: _planFrom(data['plan'] as String? ?? 'monthly'),
        expiresAt: DateTime.parse(data['expires_at'] as String),
        activatedAt:
            DateTime.parse((data['activated_at'] ?? now.toIso8601String())
                as String),
        lastVerifiedAt: now,
        deviceId: deviceId,
      );
      // Refresh the session so the new shop_id claim lands in the JWT.
      try {
        await Supabase.instance.client.auth.refreshSession();
      } catch (_) {}
      return ActivationResult.success(await _save(lic));
    } catch (e) {
      return ActivationResult.failure('network_error');
    }
  }

  Future<CachedLicense> _localTrial(String key, String deviceId) {
    final now = DateTime.now();
    return _save(CachedLicense(
      key: key,
      shopId: 'demo-shop',
      plan: LicensePlan.trial,
      expiresAt: now.add(const Duration(days: 14)),
      activatedAt: now,
      lastVerifiedAt: now,
      deviceId: deviceId,
    )).then((v) => v!);
  }

  /// Grants a one-time free 2-month trial. When online it goes through the
  /// `start_trial` Edge Function (server-tracked per device, so it can't be
  /// farmed by reinstalling, and stamps the shop_id claim for sync); offline it
  /// falls back to a local trial.
  Future<CachedLicense?> startFreeTrial() async {
    if (await _settings.trialUsed()) return null;
    final deviceId = await _settings.deviceId();
    final now = DateTime.now();

    if (Env.hasBackend) {
      try {
        final profile = await _settings.shopProfile();
        final res = await Supabase.instance.client.functions.invoke(
          'start_trial',
          body: {'device_id': deviceId, 'shop_name': profile.name},
        );
        final data = res.data as Map<String, dynamic>;
        if (data['ok'] == true) {
          final lic = CachedLicense(
            key: data['key'] as String,
            shopId: data['shop_id'] as String,
            plan: LicensePlan.trial,
            expiresAt: DateTime.parse(data['expires_at'] as String),
            activatedAt: DateTime.parse(
                (data['activated_at'] ?? now.toIso8601String()) as String),
            lastVerifiedAt: now,
            deviceId: deviceId,
          );
          try {
            await Supabase.instance.client.auth.refreshSession();
          } catch (_) {}
          await _settings.markTrialUsed();
          return _save(lic);
        }
      } catch (_) {/* fall back to a local trial */}
    }

    final lic = await _save(CachedLicense(
      key: 'FREE-TRIAL',
      shopId: 'trial-${deviceId.replaceAll('-', '').substring(0, 10)}',
      plan: LicensePlan.trial,
      expiresAt: now.add(const Duration(days: 60)),
      activatedAt: now,
      lastVerifiedAt: now,
      deviceId: deviceId,
    ));
    await _settings.markTrialUsed();
    return lic;
  }

  Future<void> deactivate() => _settings.clearLicense();
}

LicensePlan _planFrom(String s) => switch (s) {
      'yearly' => LicensePlan.yearly,
      'monthly' => LicensePlan.monthly,
      _ => LicensePlan.trial,
    };
