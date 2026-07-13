import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../features/invoices/receipt_data.dart';
import '../local/database.dart';

/// Device-scoped key/value settings (not synced). Backs printer config,
/// shop receipt header/footer, etc.
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  static const _kPaperSize = 'printer.paper_size';
  static const _kPrinterMac = 'printer.mac';
  static const _kPrinterName = 'printer.name';
  static const _kShopName = 'shop.name';
  static const _kShopAddress = 'shop.address';
  static const _kShopPhone = 'shop.phone';
  static const _kReceiptFooter = 'receipt.footer';
  static const _kTrackStock = 'shop.track_stock';

  Future<String?> _get(String key) async {
    final row = await (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> _set(String key, String value) {
    return _db.into(_db.appSettings).insertOnConflictUpdate(
        AppSettingsCompanion(key: Value(key), value: Value(value)));
  }

  Stream<PrinterConfig> watchPrinterConfig() {
    return _db.select(_db.appSettings).watch().map((rows) {
      final map = {for (final r in rows) r.key: r.value};
      return PrinterConfig(
        paper: map[_kPaperSize] == 'mm80' ? PaperSize.mm80 : PaperSize.mm58,
        mac: map[_kPrinterMac],
        name: map[_kPrinterName],
      );
    });
  }

  Future<PrinterConfig> printerConfig() async {
    return PrinterConfig(
      paper: (await _get(_kPaperSize)) == 'mm80'
          ? PaperSize.mm80
          : PaperSize.mm58,
      mac: await _get(_kPrinterMac),
      name: await _get(_kPrinterName),
    );
  }

  Future<void> setPaperSize(PaperSize size) =>
      _set(_kPaperSize, size == PaperSize.mm80 ? 'mm80' : 'mm58');

  Future<void> setPrinter(String mac, String name) async {
    await _set(_kPrinterMac, mac);
    await _set(_kPrinterName, name);
  }

  // ---- License cache + device identity ------------------------------------

  static const _kLicense = 'license.json';
  static const _kDeviceId = 'device.id';
  static const _kLocale = 'app.locale';

  /// Persisted UI language ('en' | 'my'); null until the user has chosen.
  Future<String?> savedLocale() => _get(_kLocale);
  Future<void> saveLocale(String code) => _set(_kLocale, code);

  /// Stable per-install device id (generated once, used for license binding).
  Future<String> deviceId() async {
    final existing = await _get(_kDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    await _set(_kDeviceId, id);
    return id;
  }

  Future<String?> licenseJson() => _get(_kLicense);
  Future<void> setLicenseJson(String json) => _set(_kLicense, json);

  // One free trial per install.
  static const _kTrialUsed = 'license.trial_used';
  Future<bool> trialUsed() async => (await _get(_kTrialUsed)) == 'true';
  Future<void> markTrialUsed() => _set(_kTrialUsed, 'true');

  // Cached vendor config (payment accounts + support contact), refreshed from
  // the backend `app_config` table so it survives offline.
  static const _kVendorConfig = 'vendor.config.json';
  Future<String?> vendorConfigJson() => _get(_kVendorConfig);
  Future<void> setVendorConfigJson(String json) =>
      _set(_kVendorConfig, json);
  Future<void> clearLicense() {
    return (_db.delete(_db.appSettings)
          ..where((s) => s.key.equals(_kLicense)))
        .go();
  }

  // ---- Sync cursors (per-table high-water mark of pulled updated_at) -------

  Future<DateTime?> syncCursor(String table) async {
    final raw = await _get('sync.cursor.$table');
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> setSyncCursor(String table, DateTime value) =>
      _set('sync.cursor.$table', value.toUtc().toIso8601String());

  Future<ShopProfile> shopProfile() async {
    return ShopProfile(
      name: (await _get(_kShopName)) ?? 'My Shop',
      address: await _get(_kShopAddress),
      phone: await _get(_kShopPhone),
      footer: await _get(_kReceiptFooter),
    );
  }

  /// Whether the shop tracks inventory. When false the app runs "invoice
  /// only": no stock badges/alerts, no decrement on sale. Defaults to true.
  Future<bool> trackStock() async => (await _get(_kTrackStock)) != 'false';

  Future<void> setTrackStock(bool value) =>
      _set(_kTrackStock, value ? 'true' : 'false');

  Stream<bool> watchTrackStock() => _watchBool(_kTrackStock, true);

  Stream<bool> _watchBool(String key, bool defaultValue) {
    return _db.select(_db.appSettings).watch().map((rows) {
      final row = rows.firstWhere(
        (r) => r.key == key,
        orElse: () =>
            AppSetting(key: key, value: defaultValue ? 'true' : 'false'),
      );
      return row.value != 'false';
    });
  }

  Future<void> saveShopProfile(ShopProfile p) async {
    await _set(_kShopName, p.name);
    if (p.address != null) await _set(_kShopAddress, p.address!);
    if (p.phone != null) await _set(_kShopPhone, p.phone!);
    if (p.footer != null) await _set(_kReceiptFooter, p.footer!);
  }
}

class PrinterConfig {
  final PaperSize paper;
  final String? mac;
  final String? name;
  const PrinterConfig({required this.paper, this.mac, this.name});

  bool get hasPrinter => mac != null && mac!.isNotEmpty;
}

class ShopProfile {
  final String name;
  final String? address;
  final String? phone;
  final String? footer;
  const ShopProfile({required this.name, this.address, this.phone, this.footer});
}
