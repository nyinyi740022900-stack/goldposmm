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
      setState(() {
        _licenses = licenses;
        _payments = payments;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MM POS Admin'),
          bottom: TabBar(tabs: [
            Tab(text: 'Licenses (${_licenses?.length ?? 0})'),
            Tab(text: 'Payments (${_payments?.length ?? 0})'),
          ]),
          actions: [
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
                    _PaymentsTab(
                      rows: _payments ?? const [],
                      onApprove: _approvePayment,
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

  Future<void> _approvePayment(Map<String, dynamic> payment) async {
    final months = await showDialog<int>(
      context: context,
      builder: (_) => const _ApproveDialog(),
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
          title: Text('${r['amount']} Ks  ·  ${r['method']}'),
          subtitle: Text(
              'Shop: ${r['shop_id']}  ·  Key: ${r['license_key']}\n'
              'Txn: ${r['ref_no'] ?? '—'}  ·  ${_date(r['created_at'])}'),
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

class _GenerateKeyDialog extends StatefulWidget {
  const _GenerateKeyDialog();
  @override
  State<_GenerateKeyDialog> createState() => _GenerateKeyDialogState();
}

class _GenerateKeyDialogState extends State<_GenerateKeyDialog> {
  final _shopId = TextEditingController();
  final _months = TextEditingController(text: '1');
  String _plan = 'monthly';

  @override
  void dispose() {
    _shopId.dispose();
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

class _ApproveDialog extends StatefulWidget {
  const _ApproveDialog();
  @override
  State<_ApproveDialog> createState() => _ApproveDialogState();
}

class _ApproveDialogState extends State<_ApproveDialog> {
  final _months = TextEditingController(text: '1');
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
  final String plan;
  final int months;
  const _KeyRequest(
      {required this.shopId, required this.plan, required this.months});
}

String _date(dynamic v) {
  if (v == null) return '—';
  final s = '$v';
  return s.length >= 10 ? s.substring(0, 10) : s;
}
