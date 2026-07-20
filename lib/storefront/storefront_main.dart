import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env.dart';
import 'storefront_app.dart';

/// Separate entry point for the public B2B2C storefront (Flutter Web).
///   flutter run   -d chrome -t lib/storefront/storefront_main.dart --dart-define-from-file=env.local.json
///   flutter build web        -t lib/storefront/storefront_main.dart --dart-define-from-file=env.local.json
///
/// Customers are anonymous — the app only holds the anon key; all catalog
/// reads and guest-order writes go through the `storefront` Edge Function.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Env.hasBackend) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
  }
  runApp(const StorefrontApp());
}
