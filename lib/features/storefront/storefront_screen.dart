import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import 'storefront_repository.dart';

final storefrontRepositoryProvider = Provider<StorefrontRepository>((ref) {
  return StorefrontRepository(ref.watch(shopIdProvider));
});

final myStorefrontProvider = FutureProvider<StorefrontRow?>((ref) {
  return ref.watch(storefrontRepositoryProvider).mine();
});

/// Owner screen to publish/manage the shop's public web storefront.
class StorefrontScreen extends ConsumerStatefulWidget {
  const StorefrontScreen({super.key});

  @override
  ConsumerState<StorefrontScreen> createState() => _StorefrontScreenState();
}

class _StorefrontScreenState extends ConsumerState<StorefrontScreen> {
  final _name = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final l = AppLocalizations.of(context);
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.storefrontNeedsName)));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(storefrontRepositoryProvider)
          .publish(displayName: _name.text.trim());
      ref.invalidate(myStorefrontProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(myStorefrontProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.storefrontTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (row) => row == null
            ? _publishForm(l)
            : _manageView(l, row),
      ),
    );
  }

  Widget _publishForm(AppLocalizations l) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l.storefrontDesc),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l.storefrontDisplayName,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _publish,
          icon: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.public),
          label: Text(l.storefrontPublish),
        ),
      ],
    );
  }

  Widget _manageView(AppLocalizations l, StorefrontRow row) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.storefrontEnabled),
          value: row.enabled,
          onChanged: (v) async {
            await ref.read(storefrontRepositoryProvider).setEnabled(v);
            ref.invalidate(myStorefrontProvider);
          },
        ),
        const SizedBox(height: 8),
        Text(l.storefrontYourLink,
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Card(
          child: ListTile(
            title: Text(row.url),
            trailing: IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: row.url));
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l.storefrontCopied)));
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(l.storefrontShare,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
