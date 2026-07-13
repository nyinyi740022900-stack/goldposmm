/// Environment configuration.
///
/// Supply real values at build/run time with --dart-define, e.g.:
///   flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=eyJ...
///
/// The anon key is safe to ship (RLS enforces access). The service key must
/// NEVER be embedded in the app — it lives only in Supabase Edge Functions.
class Env {
  const Env._();

  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  /// Sentry DSN for crash reporting. Empty → crash reporting disabled.
  static const String sentryDsn =
      String.fromEnvironment('SENTRY_DSN', defaultValue: '');
  static bool get hasCrashReporting => sentryDsn.isNotEmpty;

  /// When false, the app runs fully offline (sync disabled). Lets Phase 0/1
  /// run before the Supabase project exists.
  static bool get hasBackend =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
