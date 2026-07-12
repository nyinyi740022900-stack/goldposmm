import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/printing/printing_providers.dart';

const supportedLocaleCodes = {'my', 'en'};
const defaultLocaleCode = 'my';

/// Holds the active UI language and persists the user's choice so it is stable
/// across launches. Defaults to Burmese; the system locale never overrides it.
class LocaleController extends StateNotifier<String> {
  LocaleController(this._ref) : super(defaultLocaleCode) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final saved = await _ref.read(settingsRepositoryProvider).savedLocale();
    if (saved != null && supportedLocaleCodes.contains(saved)) {
      state = saved;
    }
  }

  Future<void> set(String code) async {
    if (!supportedLocaleCodes.contains(code)) return;
    state = code;
    await _ref.read(settingsRepositoryProvider).saveLocale(code);
  }
}

final localeControllerProvider =
    StateNotifierProvider<LocaleController, String>((ref) {
  return LocaleController(ref);
});
