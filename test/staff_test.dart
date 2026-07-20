import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_pos/data/local/database.dart';
import 'package:mm_pos/data/repositories/settings_repository.dart';
import 'package:mm_pos/features/printing/printing_providers.dart';
import 'package:mm_pos/features/staff/staff_providers.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository settings;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    settings = SettingsRepository(db);
    container = ProviderContainer(overrides: [
      settingsRepositoryProvider.overrideWithValue(settings),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  StaffController ctrl() => container.read(staffControllerProvider);

  test('defaults to owner role', () async {
    expect(await settings.staffRole(), 'owner');
  });

  test('entering cashier mode persists', () async {
    await ctrl().enterCashierMode();
    expect(await settings.staffRole(), 'cashier');
  });

  test('unlockOwner succeeds with no PIN set', () async {
    await ctrl().enterCashierMode();
    expect(await ctrl().unlockOwner(''), isTrue);
    expect(await settings.staffRole(), 'owner');
  });

  test('unlockOwner rejects a wrong PIN and stays cashier', () async {
    await ctrl().setPin('1234');
    await ctrl().enterCashierMode();
    expect(await ctrl().unlockOwner('9999'), isFalse);
    expect(await settings.staffRole(), 'cashier');
    // Correct PIN unlocks.
    expect(await ctrl().unlockOwner('1234'), isTrue);
    expect(await settings.staffRole(), 'owner');
  });
}
