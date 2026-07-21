import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../printing/printing_providers.dart';

/// Roles in privilege order (higher index = more access). Device-local, not
/// synced — it's a per-device operating mode, set by the owner before handing
/// the phone to staff.
const staffRoles = <String>['cashier', 'manager', 'owner'];

int _roleLevel(String role) {
  final i = staffRoles.indexOf(role);
  return i < 0 ? 0 : i;
}

final staffRoleProvider = StreamProvider<String>((ref) {
  return ref.watch(settingsRepositoryProvider).watchStaffRole();
});

/// True when the current device mode is owner (or still loading, so the UI
/// never briefly hides owner controls from the owner). Gates Analytics,
/// Storefront, Delivery-carrier config, and staff-mode/License management.
final isOwnerProvider = Provider<bool>((ref) {
  return (ref.watch(staffRoleProvider).valueOrNull ?? 'owner') == 'owner';
});

/// True for owner or manager. Gates Inventory add/edit — a manager runs stock
/// day-to-day but doesn't see business analytics or shop settings.
final canEditInventoryProvider = Provider<bool>((ref) {
  final role = ref.watch(staffRoleProvider).valueOrNull ?? 'owner';
  return role == 'owner' || role == 'manager';
});

/// Switches the device's staff role and manages the owner PIN. Downgrading
/// privilege (owner→manager, owner→cashier, manager→cashier) is always free —
/// the current user is already at least as trusted as the target. Upgrading
/// (cashier→manager, cashier→owner, manager→owner) requires the correct PIN
/// (or succeeds if no PIN has been set yet).
class StaffController {
  StaffController(this._ref);
  final Ref _ref;

  Future<bool> hasPin() async =>
      (await _ref.read(settingsRepositoryProvider).staffPin())?.isNotEmpty ??
      false;

  Future<void> setPin(String pin) =>
      _ref.read(settingsRepositoryProvider).setStaffPin(pin);

  /// Attempts to switch to [targetRole]. [pin] is required only when the
  /// switch is an upgrade in privilege; ignored for downgrades. Returns false
  /// on a wrong PIN (role is left unchanged).
  Future<bool> switchRole(String targetRole, {String? pin}) async {
    final repo = _ref.read(settingsRepositoryProvider);
    final current = await repo.staffRole();
    if (_roleLevel(targetRole) > _roleLevel(current)) {
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
