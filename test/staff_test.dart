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

  test('switching to staff never needs a PIN', () async {
    expect(await ctrl().switchRole('staff'), isTrue);
    expect(await settings.staffRole(), 'staff');
  });

  test('switching back to owner with no PIN set succeeds', () async {
    await ctrl().switchRole('staff');
    expect(await ctrl().switchRole('owner', pin: ''), isTrue);
    expect(await settings.staffRole(), 'owner');
  });

  test('switching to owner with a wrong PIN fails and stays staff', () async {
    await ctrl().setPin('1234');
    await ctrl().switchRole('staff');
    expect(await ctrl().switchRole('owner', pin: '9999'), isFalse);
    expect(await settings.staffRole(), 'staff');
    // Correct PIN succeeds.
    expect(await ctrl().switchRole('owner', pin: '1234'), isTrue);
    expect(await settings.staffRole(), 'owner');
  });

  test('switching to staff needs no PIN even when one is set', () async {
    await ctrl().setPin('1234');
    expect(await ctrl().switchRole('staff'), isTrue);
    expect(await settings.staffRole(), 'staff');
  });
}
