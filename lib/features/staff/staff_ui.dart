import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'staff_providers.dart';

String staffRoleLabel(AppLocalizations l, String role) {
  return role == 'owner' ? l.staffRoleOwner : l.staffRoleStaff;
}

/// Wraps owner-only content. In staff mode it shows a lock placeholder
/// instead of [child].
class OwnerOnlyGate extends ConsumerWidget {
  const OwnerOnlyGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isOwnerProvider)) return child;
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline,
                size: 56, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text(l.staffOwnerOnly,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(l.staffOwnerOnlyDesc, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// A small pill for app bars showing that the device is in staff mode.
class StaffBadge extends ConsumerWidget {
  const StaffBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isOwnerProvider)) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.badge_outlined, size: 14),
          const SizedBox(width: 4),
          Text(l.staffBadge, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

/// Prompts for a numeric PIN. Returns the entered value or null if cancelled.
Future<String?> promptPin(BuildContext context, String title) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        decoration: InputDecoration(
          hintText: AppLocalizations.of(ctx).staffPinHint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(AppLocalizations.of(ctx).commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
        ),
      ],
    ),
  );
}

/// Settings section to switch between Owner and Staff mode, and manage the
/// owner PIN. Switching to Staff is free; switching to Owner prompts for the
/// PIN. Deliberately just two modes — a finer-grained role tier was tried and
/// folded back into this for simplicity.
class StaffModeCard extends ConsumerWidget {
  const StaffModeCard({super.key});

  Future<void> _switchTo(
      BuildContext context, WidgetRef ref, String target) async {
    final l = AppLocalizations.of(context);
    final ctrl = ref.read(staffControllerProvider);

    String? pin;
    if (target == 'owner') {
      pin = await promptPin(context, l.staffEnterPin);
      if (pin == null) return; // cancelled
    }
    if (!context.mounted) return;
    final ok = await ctrl.switchRole(target, pin: pin);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.staffWrongPin)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final role = ref.watch(staffRoleProvider).valueOrNull ?? 'owner';
    final isOwner = role == 'owner';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Icon(isOwner ? Icons.verified_user : Icons.badge_outlined),
          title: Text(l.staffMode),
          subtitle: Text(l.staffCurrentRole(staffRoleLabel(l, role))),
        ),
        for (final target in staffRoles)
          if (target != role)
            ListTile(
              leading: Icon(target == 'owner'
                  ? Icons.lock_open_outlined
                  : Icons.badge_outlined),
              title: Text(l.staffSwitchTo(staffRoleLabel(l, target))),
              onTap: () => _switchTo(context, ref, target),
            ),
        if (isOwner)
          ListTile(
            leading: const Icon(Icons.pin_outlined),
            title: Text(l.staffSetPin),
            onTap: () async {
              final pin = await promptPin(context, l.staffSetPin);
              if (pin == null || pin.isEmpty) return;
              await ref.read(staffControllerProvider).setPin(pin);
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(l.staffPinSaved)));
              }
            },
          ),
      ],
    );
  }
}
