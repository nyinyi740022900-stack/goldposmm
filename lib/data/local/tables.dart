import 'package:drift/drift.dart';

/// Common columns every syncable table carries. Mixed into table definitions.
///
/// - [id] is a client-generated UUID (offline-first: device can create rows
///   without a server round-trip).
/// - [updatedAt] drives last-write-wins conflict resolution.
/// - [isDeleted] is a tombstone so deletes propagate through sync.
/// - [dirty] marks rows with local changes not yet pushed to the server.
mixin SyncColumns on Table {
  TextColumn get id => text()();
  TextColumn get shopId => text()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();
}

class Categories extends Table with SyncColumns {
  TextColumn get name => text()();
  IntColumn get sort => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class Products extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get sku => text().nullable()();
  TextColumn get barcode => text().nullable()();
  TextColumn get categoryId => text().nullable()();
  IntColumn get costPrice => integer().withDefault(const Constant(0))();
  IntColumn get salePrice => integer().withDefault(const Constant(0))();
  TextColumn get unit => text().withDefault(const Constant('pcs'))();
  TextColumn get imagePath => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Denormalized current stock quantity per product. The authoritative ledger
/// is [StockMovements]; this row is the fast-read cached total.
class StockLevels extends Table with SyncColumns {
  TextColumn get productId => text()();
  IntColumn get quantity => integer().withDefault(const Constant(0))();
  IntColumn get reorderLevel => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class StockMovements extends Table with SyncColumns {
  TextColumn get productId => text()();

  /// purchase | sale | adjustment | return
  TextColumn get type => text()();
  IntColumn get qtyDelta => integer()();
  IntColumn get unitCost => integer().withDefault(const Constant(0))();
  TextColumn get refId => text().nullable()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A finalized sale. **Append-only** — once written it is never updated, so
/// it can never conflict during sync. Corrections are separate reversal sales.
class Sales extends Table with SyncColumns {
  TextColumn get invoiceNo => text()();
  TextColumn get staffId => text().nullable()();
  IntColumn get subtotal => integer().withDefault(const Constant(0))();
  IntColumn get discount => integer().withDefault(const Constant(0))();
  IntColumn get tax => integer().withDefault(const Constant(0))();
  IntColumn get total => integer().withDefault(const Constant(0))();
  IntColumn get paid => integer().withDefault(const Constant(0))();
  IntColumn get changeDue => integer().withDefault(const Constant(0))();

  /// cash | kbzpay | wavepay | ayapay | cbpay
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  TextColumn get customerName => text().nullable()();
  TextColumn get customerPhone => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get finalizedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class SaleItems extends Table with SyncColumns {
  TextColumn get saleId => text()();
  TextColumn get productId => text()();

  /// Snapshots of name/price at sale time so history is stable even if the
  /// product is later renamed or repriced.
  TextColumn get nameSnapshot => text()();
  IntColumn get priceSnapshot => integer()();
  IntColumn get qty => integer()();
  IntColumn get lineTotal => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Payments extends Table with SyncColumns {
  TextColumn get saleId => text()();

  /// cash | kbzpay | wavepay | ayapay | cbpay
  TextColumn get method => text()();
  IntColumn get amount => integer()();
  TextColumn get refNo => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A renewal payment the owner recorded locally (KBZPay/Wave/cash). Synced to
/// the server so a human/automation can reconcile it against the license.
class LicensePayments extends Table with SyncColumns {
  TextColumn get licenseKey => text()();

  /// cash | kbzpay | wavepay | ayapay | cbpay
  TextColumn get method => text()();
  IntColumn get amount => integer()();
  TextColumn get refNo => text().nullable()();
  TextColumn get note => text().nullable()();

  /// The shop's own display name (from Shop profile), so the admin console
  /// shows who paid rather than the internal shop id.
  TextColumn get shopName => text().nullable()();
  BoolColumn get reconciled => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// A repayment a customer made against their outstanding credit (အကြွေး).
/// Customers are keyed by [customerName] (the same free-text field carried on
/// [Sales]); a credit sale is a sale with `paymentMethod = 'credit'` where
/// `paid < total`. Outstanding per customer = Σ(credit sale total − paid) −
/// Σ(creditPayments.amount). Synced like every other ledger row.
class CreditPayments extends Table with SyncColumns {
  TextColumn get customerName => text()();

  /// cash | kbzpay | wavepay | ayapay | cbpay
  TextColumn get method => text().withDefault(const Constant('cash'))();
  IntColumn get amount => integer()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Simple local key/value store for device-scoped app settings (printer MAC,
/// paper size, selected language, etc.). Not synced.
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Outbox of local mutations awaiting push to Supabase. Drained by SyncEngine.
class Outbox extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get entityTable => text()();
  TextColumn get rowId => text()();

  /// upsert | delete
  TextColumn get op => text()();

  /// JSON payload of the row at enqueue time.
  TextColumn get payload => text()();
  DateTimeColumn get enqueuedAt =>
      dateTime().withDefault(currentDateAndTime)();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
}
