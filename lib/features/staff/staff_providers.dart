import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../printing/printing_providers.dart';

/// Device-local staff role: `'owner'` (full access) or `'cashier'`
/// (restricted). Not synced — it's a per-device operating mode, set by the
/// owner before handing the phone to staff.
final staffRoleProvider = StreamProvider<String>((ref) {
  return ref.watch(settingsRepositoryProvider).watchStaffRole();
});

/// Convenience: true when the current device mode is owner (or still loading,
/// so the UI never briefly hides owner controls from the owner).
final isOwnerProvider = Provider<bool>((ref) {
  return (ref.watch(staffRoleProvider).valueOrNull ?? 'owner') == 'owner';
});

/// Actions for switching modes. Leaving cashier mode requires the owner PIN
/// (if one is set); entering cashier mode is free.
class StaffController {
  StaffController(this._ref);
  final Ref _ref;

  Future<void> enterCashierMode() =>
      _ref.read(settingsRepositoryProvider).setStaffRole('cashier');

  Future<bool> hasPin() async =>
      (await _ref.read(settingsRepositoryProvider).staffPin())?.isNotEmpty ??
      false;

  Future<void> setPin(String pin) =>
      _ref.read(settingsRepositoryProvider).setStaffPin(pin);

  /// Returns true and switches to owner if [pin] matches (or no PIN is set).
  Future<bool> unlockOwner(String pin) async {
    final repo = _ref.read(settingsRepositoryProvider);
    final saved = await repo.staffPin();
    if (saved != null && saved.isNotEmpty && saved != pin) return false;
    await repo.setStaffRole('owner');
    return true;
  }
}

final staffControllerProvider =
    Provider<StaffController>((ref) => StaffController(ref));
