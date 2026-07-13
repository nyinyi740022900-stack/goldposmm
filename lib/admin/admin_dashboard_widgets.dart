part of 'admin_dashboard_screen.dart';

class _LicensesTab extends StatelessWidget {
  const _LicensesTab({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const Center(child: Text('No licenses yet.'));
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = rows[i];
        final status = '${r['status']}';
        return ListTile(
          leading: Icon(Icons.vpn_key,
              color: status == 'active' ? Colors.green : Colors.orange),
          title: SelectableText('${r['key']}'),
          subtitle: Text(
              'Shop: ${r['shop_id']}  ·  ${r['plan']}  ·  $status\n'
              'Expires: ${_date(r['expires_at'])}  ·  '
              'Device: ${r['device_id'] ?? '—'}'),
          isThreeLine: true,
        );
      },
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(child: Text('No key issues / renewals yet.'));
    }
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = rows[i];
        final isExtend = r['action'] == 'extend';
        return ListTile(
          leading: Icon(isExtend ? Icons.more_time : Icons.vpn_key,
              color: isExtend ? Colors.blue : Colors.green),
          title: Text(
              '${isExtend ? 'Extended' : 'Issued'}  ·  ${r['months']} mo  ·  ${r['shop_name'] ?? '—'}'),
          subtitle: Text(
              'Key: ${r['key']}  ·  Device: ${r['device_id'] ?? '—'}\n'
              'New expiry: ${_date(r['expires_at'])}  ·  ${_date(r['created_at'])}'),
          isThreeLine: true,
        );
      },
    );
  }
}

class _RequestsTab extends StatelessWidget {
  const _RequestsTab({required this.rows, required this.onIssue});
  final List<Map<String, dynamic>> rows;
  final Future<void> Function(Map<String, dynamic>) onIssue;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(child: Text('No subscription requests.'));
    }
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = rows[i];
        final fulfilled = r['status'] == 'fulfilled';
        return ListTile(
          leading: Icon(
            fulfilled ? Icons.check_circle : Icons.hourglass_top,
            color: fulfilled ? Colors.green : Colors.orange,
          ),
          title: Text(
              '${r['shop_name']}  ·  ${r['amount']} Ks  ·  ${r['method']}  ·  ${r['months']} mo'),
          subtitle: Text(
              'Phone: ${r['phone'] ?? '—'}  ·  Txn: ${r['ref_no'] ?? '—'}\n'
              'Device: ${r['device_id'] ?? '—'}  ·  ${_date(r['created_at'])}'
              '${fulfilled ? '  ·  Key: ${r['issued_key']}' : ''}'),
          isThreeLine: true,
          trailing: fulfilled
              ? const Text('Issued')
              : FilledButton(
                  onPressed: () => onIssue(r),
                  child: const Text('Issue key'),
                ),
        );
      },
    );
  }
}

class _GenerateKeyDialog extends StatefulWidget {
  const _GenerateKeyDialog();
  @override
  State<_GenerateKeyDialog> createState() => _GenerateKeyDialogState();
}

class _GenerateKeyDialogState extends State<_GenerateKeyDialog> {
  final _shopId = TextEditingController();
  final _shopName = TextEditingController();
  final _months = TextEditingController(text: '1');
  String _plan = 'monthly';

  @override
  void dispose() {
    _shopId.dispose();
    _shopName.dispose();
    _months.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generate license key'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _shopId,
            decoration: const InputDecoration(
                labelText: 'Shop ID (any stable identifier)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _shopName,
            decoration:
                const InputDecoration(labelText: 'Shop name (display)'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _plan,
            decoration: const InputDecoration(labelText: 'Plan'),
            items: const [
              DropdownMenuItem(value: 'monthly', child: Text('monthly')),
              DropdownMenuItem(value: 'yearly', child: Text('yearly')),
            ],
            onChanged: (v) => setState(() => _plan = v ?? 'monthly'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _months,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Duration (months)'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final shop = _shopId.text.trim();
            if (shop.isEmpty) return;
            Navigator.pop(
              context,
              _KeyRequest(
                shopId: shop,
                shopName: _shopName.text.trim(),
                plan: _plan,
                months: int.tryParse(_months.text.trim()) ?? 1,
              ),
            );
          },
          child: const Text('Generate'),
        ),
      ],
    );
  }
}

class _OfflineRequest {
  final String shopId;
  final String shopName;
  final String plan;
  final int months;
  final String deviceId;
  const _OfflineRequest(
      this.shopId, this.shopName, this.plan, this.months, this.deviceId);
}

class _OfflineCodeDialog extends StatefulWidget {
  const _OfflineCodeDialog();
  @override
  State<_OfflineCodeDialog> createState() => _OfflineCodeDialogState();
}

class _OfflineCodeDialogState extends State<_OfflineCodeDialog> {
  final _shopId = TextEditingController();
  final _shopName = TextEditingController();
  final _months = TextEditingController(text: '1');
  final _device = TextEditingController();
  String _plan = 'monthly';

  @override
  void dispose() {
    for (final c in [_shopId, _shopName, _months, _device]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generate offline code'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: _shopId,
                decoration: const InputDecoration(labelText: 'Shop ID')),
            const SizedBox(height: 8),
            TextField(
                controller: _shopName,
                decoration: const InputDecoration(labelText: 'Shop name')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _plan,
              decoration: const InputDecoration(labelText: 'Plan'),
              items: const [
                DropdownMenuItem(value: 'monthly', child: Text('monthly')),
                DropdownMenuItem(value: 'yearly', child: Text('yearly')),
              ],
              onChanged: (v) => setState(() => _plan = v ?? 'monthly'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _months,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Duration (months)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _device,
              decoration: const InputDecoration(
                  labelText: 'Bind to App Reference ID (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final shop = _shopId.text.trim();
            if (shop.isEmpty) return;
            Navigator.pop(
              context,
              _OfflineRequest(
                shop,
                _shopName.text.trim(),
                _plan,
                int.tryParse(_months.text.trim()) ?? 1,
                _device.text.trim(),
              ),
            );
          },
          child: const Text('Generate'),
        ),
      ],
    );
  }
}

class _CodePromptDialog extends StatefulWidget {
  const _CodePromptDialog(
      {required this.title, required this.label, required this.action});
  final String title;
  final String label;
  final String action;
  @override
  State<_CodePromptDialog> createState() => _CodePromptDialogState();
}

class _CodePromptDialogState extends State<_CodePromptDialog> {
  final _code = TextEditingController();
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _code,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _code.text.trim()),
          child: Text(widget.action),
        ),
      ],
    );
  }
}

class _ExtendByCodeDialog extends StatefulWidget {
  const _ExtendByCodeDialog();
  @override
  State<_ExtendByCodeDialog> createState() => _ExtendByCodeDialogState();
}

class _ExtendByCodeDialogState extends State<_ExtendByCodeDialog> {
  final _code = TextEditingController();
  final _months = TextEditingController(text: '1');
  @override
  void dispose() {
    _code.dispose();
    _months.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Extend by App Reference ID'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _code,
            decoration: const InputDecoration(
                labelText: 'App Reference ID / Shop Code'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _months,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Extend by (months)'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final code = _code.text.trim();
            if (code.isEmpty) return;
            Navigator.pop(
                context, (code, int.tryParse(_months.text.trim()) ?? 1));
          },
          child: const Text('Extend'),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _KeyRequest {
  final String shopId;
  final String shopName;
  final String plan;
  final int months;
  const _KeyRequest(
      {required this.shopId,
      required this.shopName,
      required this.plan,
      required this.months});
}

/// Editable vendor config (payment accounts, support, renewal prices).
class _ConfigTab extends StatefulWidget {
  const _ConfigTab({required this.initial, required this.onSave});
  final Map<String, String> initial;
  final Future<void> Function(Map<String, String>) onSave;

  @override
  State<_ConfigTab> createState() => _ConfigTabState();
}

class _ConfigTabState extends State<_ConfigTab> {
  static const _fields = <String, String>{
    'pay.kbzpay.name': 'KBZPay account name',
    'pay.kbzpay.number': 'KBZPay number',
    'pay.wavepay.name': 'WavePay account name',
    'pay.wavepay.number': 'WavePay number',
    'support.viber': 'Support Viber number',
    'price.monthly': 'Monthly price (Ks)',
    'price.yearly': 'Yearly price (Ks)',
  };
  late final Map<String, TextEditingController> _controllers = {
    for (final k in _fields.keys)
      k: TextEditingController(text: widget.initial[k] ?? ''),
  };
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final values = {
      for (final e in _controllers.entries) e.key: e.value.text.trim(),
    };
    await widget.onSave(values);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final e in _fields.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _controllers[e.key],
              keyboardType: e.key.startsWith('price')
                  ? TextInputType.number
                  : TextInputType.text,
              decoration: InputDecoration(
                labelText: e.value,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save),
          label: const Text('Save config'),
        ),
      ],
    );
  }
}

String _date(dynamic v) {
  if (v == null) return '—';
  final s = '$v';
  return s.length >= 10 ? s.substring(0, 10) : s;
}
