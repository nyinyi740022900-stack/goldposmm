import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env.dart';
import 'admin_api.dart';
import 'admin_dashboard_screen.dart';
import 'admin_login_screen.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MM POS Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00695C)),
        useMaterial3: true,
      ),
      home: const _AuthGate(),
    );
  }
}

/// Routes between login and dashboard based on the Supabase auth session, and
/// blocks non-admin accounts.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  final _api = AdminApi();

  @override
  Widget build(BuildContext context) {
    if (!Env.hasBackend) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No backend configured. Run with '
              '--dart-define-from-file=env.local.json',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, _) {
        if (!_api.isSignedIn) {
          return AdminLoginScreen(api: _api, onSignedIn: _refresh);
        }
        if (!_api.isAdmin) {
          return _NotAuthorized(api: _api, onSignedOut: _refresh);
        }
        return AdminDashboardScreen(api: _api, onSignedOut: _refresh);
      },
    );
  }

  void _refresh() {
    if (mounted) setState(() {});
  }
}

class _NotAuthorized extends StatelessWidget {
  const _NotAuthorized({required this.api, required this.onSignedOut});
  final AdminApi api;
  final VoidCallback onSignedOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            const Text('This account is not an admin.'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () async {
                await api.signOut();
                onSignedOut();
              },
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
