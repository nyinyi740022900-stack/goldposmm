import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'admin_api.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen(
      {super.key, required this.api, required this.onSignedOut});
  final AdminApi api;
  final VoidCallback onSignedOut;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<Map<String, dynamic>>? _licenses;
  List<Map<String, dynamic>>? _payments;
  List<Map<String, dynamic>>? _requests;
  List<Map<String, dynamic>>? _events;
  Map<String, String>? _config;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final licenses = await widget.api.listLicenses();
      final payments = await widget.api.listPayments();
      final requests = await widget.api.listRequests();
      final events = await widget.api.listEvents();
      final config = await widget.api.getConfig();
      setState(() {
        _licenses = licenses;
        _payments = payments;
        _requests = requests;
        _events = events;
        _config = config;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingRequests =
        (_requests ?? []).where((r) => r['status'] == 'pending').length;
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MM POS Admin'),
          bottom: TabBar(isScrollable: true, tabs: [
            Tab(text: 'Licenses (${_licenses?.length ?? 0})'),
            Tab(text: 'Requests ($pendingRequests)'),
            Tab(text: 'History (${_events?.length ?? 0})'),
            Tab(text: 'Payments (${_payments?.length ?? 0})'),
            const Tab(text: 'Config'),
          ]),
          actions: [
            IconButton(
              tooltip: 'Extend by App Reference ID',
              icon: const Icon(Icons.more_time),
              onPressed: _extendByCode,
            ),
            IconButton(
              tooltip: 'Reload',
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _reload,
            ),
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await widget.api.signOut();
                widget.onSignedOut();
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _generateKey,
          icon: const Icon(Icons.add),
          label: const Text('Generate key'),
        ),
        body: _error != null
            ? _ErrorView(message: _error!, onRetry: _reload)
            : _loading && _licenses == null
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(children: [
                    _LicensesTab(rows: _licenses ?? const []),
                    _RequestsTab(
                      rows: _requests ?? const [],
                      onIssue: _issueKey,
                    ),
                    _HistoryTab(rows: _events ?? const []),
                    _PaymentsTab(
                      rows: _payments ?? const [],
                      onApprove: _approvePayment,
                    ),
                    _ConfigTab(
                      initial: _config ?? const {},
                      onSave: _saveConfig,
                    ),
                  ]),
      ),
    );
  }

  Future<void> _generateKey() async {
    final result = await showDialog<_KeyRequest>(
      context: context,
      builder: (_) => const _GenerateKeyDialog(),
    );
    if (result == null) return;
    try {
      final key = await widget.api.createLicense(
        shopId: result.shopId,
        shopName: result.shopName,
        plan: result.plan,
        months: result.months,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('License key created'),
          content: SelectableText(key,
              style: const TextStyle(
                  fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: key));
                Navigator.pop(context);
              },
              child: const Text('Copy & close'),
            ),
          ],
        ),
      );
      _reload();
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _extendByCode() async {
    final result = await showDialog<(String, int)>(
      context: context,
      builder: (_) => const _ExtendByCodeDialog(),
    );
    if (result == null) return;
    try {
      final expiry = await widget.api
          .extendByDevice(deviceId: result.$1, months: result.$2);
      _snack('Extended to $expiry');
      _reload();
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _issueKey(Map<String, dynamic> request) async {
    try {
      final key = await widget.api.fulfillRequest(
        requestId: '${request['id']}',
        months: request['months'] is int ? request['months'] as int : null,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Key issued'),
          content: SelectableText(key,
              style: const TextStyle(
                  fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: key));
                Navigator.pop(context);
              },
              child: const Text('Copy & close'),
            ),
          ],
        ),
      );
      _reload();
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _saveConfig(Map<String, String> config) async {
    try {
      await widget.api.setConfig(config);
      _snack('Config saved');
      _reload();
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _approvePayment(Map<String, dynamic> payment) async {
    // Pre-fill months from the count recorded on the payment note.
    final initialMonths = int.tryParse('${payment['note']}') ?? 1;
    final months = await showDialog<int>(
      context: context,
      builder: (_) => _ApproveDialog(initialMonths: initialMonths),
    );
    if (months == null) return;
    try {
      final expiry = await widget.api.renewLicense(
        key: '${payment['license_key']}',
        months: months,
        paymentId: '${payment['id']}',
      );
      _snack('Renewed to $expiry');
      _reload();
    } catch (e) {
      _snack('$e');
    }
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}

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

class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab({required this.rows, required this.onApprove});
  final List<Map<String, dynamic>> rows;
  final Future<void> Function(Map<String, dynamic>) onApprove;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const Center(child: Text('No payments yet.'));
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = rows[i];
        final reconciled = r['reconciled'] == true;
        return ListTile(
          leading: Icon(
            reconciled ? Icons.check_circle : Icons.pending,
            color: reconciled ? Colors.green : Colors.orange,
          ),
          title: Text(
              '${r['amount']} Ks  ·  ${r['method']}  ·  ${r['note'] != null ? '${r['note']} mo' : '—'}'),
          subtitle: Text(
              'Shop: ${r['shop_name'] ?? r['shop_id']}  ·  Device: ${r['device_id'] ?? '—'}\n'
              'Key: ${r['license_key']}  ·  Txn: ${r['ref_no'] ?? '—'}  ·  ${_date(r['created_at'])}'),
          isThreeLine: true,
          trailing: reconciled
              ? const Text('Approved')
              : FilledButton(
                  onPressed: () => onApprove(r),
                  child: const Text('Approve'),
                ),
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

class _ApproveDialog extends StatefulWidget {
  const _ApproveDialog({required this.initialMonths});
  final int initialMonths;
  @override
  State<_ApproveDialog> createState() => _ApproveDialogState();
}

class _ApproveDialogState extends State<_ApproveDialog> {
  late final _months =
      TextEditingController(text: '${widget.initialMonths}');
  @override
  void dispose() {
    _months.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Approve & extend'),
      content: TextField(
        controller: _months,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(labelText: 'Extend by (months)'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, int.tryParse(_months.text.trim()) ?? 1),
          child: const Text('Approve'),
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
