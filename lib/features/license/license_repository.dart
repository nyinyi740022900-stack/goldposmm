import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/env.dart';
import '../../data/local/database.dart';
import '../../data/repositories/settings_repository.dart';
import 'license_model.dart';
import 'license_status.dart';

/// Owns license activation, local caching, and renewal-payment recording.
///
/// Online activation calls the `activate` Edge Function (which validates the
/// key, binds the device, and sets the JWT `shop_id` claim). When no backend
/// is configured it falls back to a local 14-day trial so development and
/// offline demos keep working.
class LicenseRepository {
  LicenseRepository(this._db, this._settings);

  final AppDatabase _db;
  final SettingsRepository _settings;
  static const _uuid = Uuid();

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

  Future<void> deactivate() => _settings.clearLicense();

  /// Records a renewal payment locally and queues it for server reconciliation.
  Future<void> recordRenewalPayment({
    required String shopId,
    required String licenseKey,
    required String method,
    required int amount,
    String? refNo,
    String? note,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await _db.transaction(() async {
      await _db.into(_db.licensePayments).insert(LicensePaymentsCompanion.insert(
            id: id,
            shopId: shopId,
            licenseKey: licenseKey,
            method: method,
            amount: amount,
            refNo: Value(refNo),
            note: Value(note),
            updatedAt: Value(now),
          ));
      final row = await (_db.select(_db.licensePayments)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      await _db.into(_db.outbox).insert(OutboxCompanion.insert(
            entityTable: 'license_payments',
            rowId: id,
            op: 'upsert',
            payload: jsonEncode(row.toJson()),
          ));
    });
  }
}

LicensePlan _planFrom(String s) => switch (s) {
      'yearly' => LicensePlan.yearly,
      'monthly' => LicensePlan.monthly,
      _ => LicensePlan.trial,
    };
