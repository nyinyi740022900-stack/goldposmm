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

  test('downgrading (owner -> manager -> cashier) never needs a PIN',
      () async {
    expect(await ctrl().switchRole('manager'), isTrue);
    expect(await settings.staffRole(), 'manager');
    expect(await ctrl().switchRole('cashier'), isTrue);
    expect(await settings.staffRole(), 'cashier');
  });

  test('upgrading with no PIN set succeeds', () async {
    await ctrl().switchRole('cashier');
    expect(await ctrl().switchRole('owner', pin: ''), isTrue);
    expect(await settings.staffRole(), 'owner');
  });

  test('upgrading with a wrong PIN fails and role is unchanged', () async {
    await ctrl().setPin('1234');
    await ctrl().switchRole('cashier');
    expect(await ctrl().switchRole('manager', pin: '9999'), isFalse);
    expect(await settings.staffRole(), 'cashier');
    // Correct PIN succeeds.
    expect(await ctrl().switchRole('manager', pin: '1234'), isTrue);
    expect(await settings.staffRole(), 'manager');
  });

  test('cashier -> manager is an upgrade and also requires the PIN',
      () async {
    await ctrl().setPin('1234');
    await ctrl().switchRole('cashier');
    expect(await ctrl().switchRole('manager', pin: '0000'), isFalse);
    expect(await settings.staffRole(), 'cashier');
  });

  test('manager -> cashier is a downgrade and needs no PIN even with one set',
      () async {
    await ctrl().setPin('1234');
    await ctrl().switchRole('manager', pin: '1234');
    expect(await ctrl().switchRole('cashier'), isTrue);
    expect(await settings.staffRole(), 'cashier');
  });
}
