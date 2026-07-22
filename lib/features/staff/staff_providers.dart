import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../printing/printing_providers.dart';

/// Two device-local operating modes, not synced — set by the owner before
/// handing the phone to staff. Kept deliberately simple: 'staff' (Sell +
/// Orders only) and 'owner' (everything). A finer-grained role tier was tried
/// and folded back into this — extra roles added complexity without a clear
/// use case for a small shop.
const staffRoles = <String>['staff', 'owner'];

final staffRoleProvider = StreamProvider<String>((ref) {
  return ref.watch(settingsRepositoryProvider).watchStaffRole();
});

/// True when the current device mode is owner (or still loading, so the UI
/// never briefly hides owner controls from the owner). Gates Analytics,
/// Inventory add/edit, Storefront, Delivery-carrier config, and staff-mode/
/// License management.
final isOwnerProvider = Provider<bool>((ref) {
  return (ref.watch(staffRoleProvider).valueOrNull ?? 'owner') == 'owner';
});

/// Alias kept for call-site clarity in the Inventory screen — Inventory
/// add/edit is owner-only, same gate as everything else non-Sell/Orders.
final canEditInventoryProvider = Provider<bool>((ref) => ref.watch(isOwnerProvider));

/// Switches the device's staff role and manages the owner PIN. Switching to
/// 'staff' is always free (an owner locking the device down for a cashier);
/// switching to 'owner' requires the correct PIN (or succeeds if none is set).
class StaffController {
  StaffController(this._ref);
  final Ref _ref;

  Future<bool> hasPin() async =>
      (await _ref.read(settingsRepositoryProvider).staffPin())?.isNotEmpty ??
      false;

  Future<void> setPin(String pin) =>
      _ref.read(settingsRepositoryProvider).setStaffPin(pin);

  /// Attempts to switch to [targetRole]. [pin] is required only when
  /// switching to 'owner'. Returns false on a wrong PIN (role unchanged).
  Future<bool> switchRole(String targetRole, {String? pin}) async {
    final repo = _ref.read(settingsRepositoryProvider);
    if (targetRole == 'owner') {
      final saved = await repo.staffPin();
      if (saved != null && saved.isNotEmpty && saved != (pin ?? '')) {
        return false;
      }
    }
    await repo.setStaffRole(targetRole);
    return true;
  }
}

final staffControllerProvider =
    Provider<StaffController>((ref) => StaffController(ref));
