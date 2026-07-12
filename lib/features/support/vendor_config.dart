import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import '../../data/repositories/settings_repository.dart';

/// Vendor (company) info shown to shops: where to send license-renewal
/// payments and how to reach support. Sourced from the backend `app_config`
/// table and cached locally so it works offline.
class VendorConfig {
  final String kbzName;
  final String kbzNumber;
  final String waveName;
  final String waveNumber;
  final String supportViber;

  const VendorConfig({
    this.kbzName = '',
    this.kbzNumber = '',
    this.waveName = '',
    this.waveNumber = '',
    this.supportViber = '',
  });

  bool get hasKbz => kbzNumber.isNotEmpty;
  bool get hasWave => waveNumber.isNotEmpty;
  bool get hasSupport => supportViber.isNotEmpty;

  factory VendorConfig.fromMap(Map<String, String> m) => VendorConfig(
        kbzName: m['pay.kbzpay.name'] ?? '',
        kbzNumber: m['pay.kbzpay.number'] ?? '',
        waveName: m['pay.wavepay.name'] ?? '',
        waveNumber: m['pay.wavepay.number'] ?? '',
        supportViber: m['support.viber'] ?? '',
      );

  Map<String, String> toMap() => {
        'pay.kbzpay.name': kbzName,
        'pay.kbzpay.number': kbzNumber,
        'pay.wavepay.name': waveName,
        'pay.wavepay.number': waveNumber,
        'support.viber': supportViber,
      };

  static const empty = VendorConfig();
}

class VendorConfigRepository {
  VendorConfigRepository(this._settings);

  final SettingsRepository _settings;

  /// Returns the cached config immediately usable, refreshing from the backend
  /// in the background when online. Online failures fall back to the cache.
  Future<VendorConfig> load() async {
    if (Env.hasBackend) {
      try {
        final rows = await Supabase.instance.client
            .from('app_config')
            .select('key, value');
        final map = <String, String>{
          for (final r in (rows as List))
            (r['key'] as String): (r['value'] as String? ?? ''),
        };
        final cfg = VendorConfig.fromMap(map);
        await _settings.setVendorConfigJson(jsonEncode(cfg.toMap()));
        return cfg;
      } catch (_) {
        // fall through to cache
      }
    }
    final raw = await _settings.vendorConfigJson();
    if (raw != null) {
      try {
        final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
        return VendorConfig.fromMap(
            m.map((k, v) => MapEntry(k, '${v ?? ''}')));
      } catch (_) {}
    }
    return VendorConfig.empty;
  }
}
