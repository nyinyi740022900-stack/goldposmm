import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env.dart';
import 'admin_app.dart';

/// Separate entry point for the vendor admin dashboard (Flutter Web).
///   flutter run   -d chrome -t lib/admin/admin_main.dart --dart-define-from-file=env.local.json
///   flutter build web        -t lib/admin/admin_main.dart --dart-define-from-file=env.local.json
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Env.hasBackend) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
  }
  runApp(const AdminApp());
}
