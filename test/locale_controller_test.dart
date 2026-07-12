import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_pos/core/locale_controller.dart';
import 'package:mm_pos/core/providers.dart';
import 'package:mm_pos/data/local/database.dart';
import 'package:mm_pos/data/repositories/settings_repository.dart';

void main() {
  test('defaults to Burmese and persists the chosen locale', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    // Default before any choice.
    expect(container.read(localeControllerProvider), 'my');

    await container.read(localeControllerProvider.notifier).set('en');
    expect(container.read(localeControllerProvider), 'en');

    // Persisted to the settings store.
    expect(await SettingsRepository(db).savedLocale(), 'en');
  });

  test('ignores unsupported locale codes', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await container.read(localeControllerProvider.notifier).set('fr');
    expect(container.read(localeControllerProvider), 'my'); // unchanged
  });

  test('a fresh controller loads the previously saved locale', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await SettingsRepository(db).saveLocale('en');

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    // Trigger creation, then let the async _load() run.
    container.read(localeControllerProvider);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(container.read(localeControllerProvider), 'en');
  });
}
