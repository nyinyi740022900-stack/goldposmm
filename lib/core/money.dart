import 'package:intl/intl.dart';

/// Money value object for Myanmar Kyat (MMK).
///
/// MMK has no commonly used minor unit, so we store whole kyat as an [int].
/// All arithmetic stays in integers to avoid floating-point drift on money.
class Money implements Comparable<Money> {
  final int kyat;

  const Money(this.kyat);

  static const Money zero = Money(0);

  factory Money.fromString(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9-]'), '');
    return Money(int.tryParse(cleaned) ?? 0);
  }

  Money operator +(Money other) => Money(kyat + other.kyat);
  Money operator -(Money other) => Money(kyat - other.kyat);
  Money operator *(int qty) => Money(kyat * qty);

  bool get isNegative => kyat < 0;
  bool get isZero => kyat == 0;

  static final NumberFormat _fmt = NumberFormat('#,##0', 'en_US');

  /// e.g. `1,250`
  String get formatted => _fmt.format(kyat);

  /// e.g. `1,250 Ks` — pass the localized symbol from AppLocalizations.
  String withSymbol(String symbol) => '$formatted $symbol';

  @override
  int compareTo(Money other) => kyat.compareTo(other.kyat);

  @override
  bool operator ==(Object other) => other is Money && other.kyat == kyat;

  @override
  int get hashCode => kyat.hashCode;

  @override
  String toString() => 'Money($kyat)';
}
