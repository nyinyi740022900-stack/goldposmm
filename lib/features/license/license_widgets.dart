part of 'license_screen.dart';

String _planName(AppLocalizations l, LicensePlan plan) => switch (plan) {
      LicensePlan.yearly => l.licensePlanYearly,
      LicensePlan.monthly => l.licensePlanMonthly,
      LicensePlan.trial => l.licenseFreeTrial,
    };

/// Shows the unique App Reference ID / Shop Code (the admin extends by this).
class _RefIdTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final id = ref.watch(deviceIdProvider).valueOrNull;
    if (id == null) return const SizedBox.shrink();
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: const Icon(Icons.qr_code_2),
        title: Text(l.licenseRefId),
        subtitle: Text(id, style: const TextStyle(fontFamily: 'monospace')),
        trailing: IconButton(
          icon: const Icon(Icons.copy),
          tooltip: l.commonCopy,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: id));
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(l.copied)));
            }
          },
        ),
      ),
    );
  }
}

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
                  if (status.plan != null)
                    Text('${l.licensePlanLabel}: ${_planName(l, status.plan!)}',
                        style: Theme.of(context).textTheme.bodySmall),
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
