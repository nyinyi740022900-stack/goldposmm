import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/env.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Surface framework errors; in release these should go to a crash reporter.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    };

    // Initialize Supabase only when backend config is provided. This lets the
    // app run fully offline (no credentials required).
    if (Env.hasBackend) {
      try {
        await Supabase.initialize(
          url: Env.supabaseUrl,
          // anon key == publishable key; safe to ship (RLS enforces access).
          publishableKey: Env.supabaseAnonKey,
        );
      } catch (e) {
        // Never let a backend init failure block an offline-first app.
        debugPrint('Supabase init failed (continuing offline): $e');
      }
    }

    runApp(const ProviderScope(child: MmPosApp()));
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error');
  });
}
