import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_pos/data/local/database.dart';
import 'package:mm_pos/data/repositories/settings_repository.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository settings;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    settings = SettingsRepository(db);
  });

  tearDown(() async => db.close());

  test('onboarding is not complete on a fresh install', () async {
    expect(await settings.onboardingComplete(), isFalse);
  });

  test('marking onboarding complete persists', () async {
    await settings.markOnboardingComplete();
    expect(await settings.onboardingComplete(), isTrue);
  });
}
