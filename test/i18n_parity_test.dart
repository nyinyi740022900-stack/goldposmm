import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// QA guard: the Burmese and English ARB files must define exactly the same
/// message keys, and no message may be left empty. Catches missing or
/// forgotten translations before they ship.
void main() {
  Map<String, dynamic> load(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  // Real message keys only: drop @@locale and @-prefixed metadata.
  Set<String> messageKeys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  final en = load('lib/l10n/app_en.arb');
  final my = load('lib/l10n/app_my.arb');

  test('en and my define the same message keys', () {
    final enKeys = messageKeys(en);
    final myKeys = messageKeys(my);

    final missingInMy = enKeys.difference(myKeys);
    final missingInEn = myKeys.difference(enKeys);

    expect(missingInMy, isEmpty,
        reason: 'Burmese (my) is missing keys: $missingInMy');
    expect(missingInEn, isEmpty,
        reason: 'English (en) is missing keys: $missingInEn');
  });

  test('no translation value is empty', () {
    for (final entry in {'en': en, 'my': my}.entries) {
      for (final key in messageKeys(entry.value)) {
        final value = entry.value[key];
        expect(value is String && value.trim().isNotEmpty, isTrue,
            reason: '${entry.key} "$key" is empty');
      }
    }
  });

  test('placeholder metadata matches between locales', () {
    // If en declares placeholders for a key, my must use the same placeholder
    // tokens (e.g. {date}) so ICU formatting works in both.
    final placeholderKeys =
        en.keys.where((k) => k.startsWith('@') && en[k] is Map).toList();
    for (final metaKey in placeholderKeys) {
      final meta = en[metaKey] as Map;
      if (!meta.containsKey('placeholders')) continue;
      final key = metaKey.substring(1);
      final placeholders = (meta['placeholders'] as Map).keys.cast<String>();
      final myValue = my[key] as String?;
      if (myValue == null) continue;
      for (final ph in placeholders) {
        expect(myValue.contains('{$ph}'), isTrue,
            reason: 'my "$key" is missing placeholder {$ph}');
      }
    }
  });
}
