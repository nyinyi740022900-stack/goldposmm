import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../sell/payment_labels.dart';
import '../sell/sales_providers.dart';
import '../support/support_providers.dart';
import '../support/vendor_config.dart';
import 'license_providers.dart';
import 'license_status.dart';

class LicenseScreen extends ConsumerStatefulWidget {
  const LicenseScreen({super.key});

  @override
  ConsumerState<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends ConsumerState<LicenseScreen> {
  final _key = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final result =
          await ref.read(licenseControllerProvider.notifier).activate(_key.text);
      if (!result.ok) {
        final msg = result.errorCode == 'invalid_key' ||
                result.errorCode == 'device_mismatch'
            ? l.licenseInvalidKey
            : l.licenseActivateFailed;
        messenger.showSnackBar(SnackBar(content: Text(msg)));
      } else {
        messenger.showSnackBar(SnackBar(content: Text(l.licenseActivated)));
        _key.clear();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final result =
          await ref.read(licenseControllerProvider.notifier).refreshOnline();
      messenger.showSnackBar(SnackBar(
          content: Text(result.ok ? l.licenseRefreshed : l.licenseActivateFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(licenseControllerProvider);
    final status = state.status;

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsLicense)),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.space4),
        children: [
          _StatusCard(status: status),
          const SizedBox(height: AppTheme.space4),
          if (status.canSell) ...[
            FilledButton.tonalIcon(
              onPressed: () => _showRenewalDialog(),
              icon: const Icon(Icons.payments),
              label: Text(l.licenseRecordPayment),
            ),
            const SizedBox(height: AppTheme.space2),
            OutlinedButton.icon(
              onPressed: _busy ? null : _refresh,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              label: Text(l.licenseCheckRenewal),
            ),
            const SizedBox(height: AppTheme.space1),
            Text(l.licenseRenewHint,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppTheme.space2),
            TextButton.icon(
              onPressed: () =>
                  ref.read(licenseControllerProvider.notifier).deactivate(),
              icon: const Icon(Icons.link_off),
              label: Text(l.licenseDeactivate),
            ),
          ] else ...[
            Text(l.licenseActivateTitle,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppTheme.space1),
            Text(l.licenseGetKey,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppTheme.space3),
            TextField(
              controller: _key,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: l.licenseKeyLabel),
            ),
            const SizedBox(height: AppTheme.space3),
            FilledButton.icon(
              onPressed: _busy ? null : _activate,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
              label: Text(l.licenseActivateBtn),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showRenewalDialog() async {
    final l = AppLocalizations.of(context);
    // Load where-to-pay info (cached; refreshed online) before opening.
    final cfg = await ref.read(vendorConfigProvider.future);
    if (!mounted) return;
    final amount = TextEditingController();
    final txn = TextEditingController();
    String method = 'kbzpay';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(l.licenseRenewTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: AppTheme.space2,
                  children: [
                    for (final m in paymentMethods)
                      ChoiceChip(
                        label: Text(paymentLabel(l, m)),
                        selected: method == m,
                        onSelected: (_) => setLocal(() => method = m),
                      ),
                  ],
                ),
                _PayToCard(config: cfg, method: method),
                const SizedBox(height: AppTheme.space2),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: l.licenseAmount),
                ),
                TextField(
                  controller: txn,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: InputDecoration(labelText: l.licenseTxnId),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.commonCancel),
            ),
            FilledButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await ref.read(licenseControllerProvider.notifier)
                    .recordRenewalPayment(
                      method: method,
                      amount: int.tryParse(amount.text.trim()) ?? 0,
                      refNo: txn.text.trim().isEmpty ? null : txn.text.trim(),
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                messenger.showSnackBar(
                    SnackBar(content: Text(l.licensePaymentSaved)));
              },
              child: Text(l.commonSave),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Send the money here" card — shows the company account for the selected
/// digital method, with a copy-number button.
class _PayToCard extends StatelessWidget {
  const _PayToCard({required this.config, required this.method});

  final VendorConfig config;
  final String method;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (String name, String number) = switch (method) {
      'kbzpay' => (config.kbzName, config.kbzNumber),
      'wavepay' => (config.waveName, config.waveNumber),
      _ => ('', ''),
    };
    if (number.isEmpty) return const SizedBox(height: AppTheme.space2);

    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.space2),
      child: Card(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space3),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.licensePayTo,
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 2),
                    Text('${paymentLabel(l, method)} · $number',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (name.isNotEmpty) Text(name),
                  ],
                ),
              ),
              IconButton(
                tooltip: l.commonCopy,
                icon: const Icon(Icons.copy),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: number));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.copied)));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final LicenseStatus status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    final (String label, Color color, IconData icon) = switch (status.kind) {
      LicenseStatusKind.active =>
        (l.licenseStatusActive, Colors.green, Icons.verified),
      LicenseStatusKind.grace =>
        (l.licenseStatusGrace, Colors.orange, Icons.timelapse),
      LicenseStatusKind.expired =>
        (l.licenseStatusExpired, scheme.error, Icons.error),
      LicenseStatusKind.none =>
        (l.licenseStatusNone, scheme.outline, Icons.info_outline),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space4),
        child: Row(
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(width: AppTheme.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: color)),
                  if (status.expiresAt != null)
                    Text(l.licenseExpires(
                        DateFormat('yyyy-MM-dd').format(status.expiresAt!))),
                  if (status.kind == LicenseStatusKind.grace)
                    Text(l.licenseGraceLeft(status.graceDaysLeft),
                        style: TextStyle(color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
