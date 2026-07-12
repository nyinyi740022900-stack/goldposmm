import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import '../../core/providers.dart';
import '../../features/printing/printing_providers.dart';
import 'sync_engine.dart';

enum SyncPhase { disabled, idle, syncing, offline, error }

class SyncState {
  final SyncPhase phase;
  final DateTime? lastSyncedAt;
  final String? error;

  const SyncState({required this.phase, this.lastSyncedAt, this.error});

  SyncState copyWith({SyncPhase? phase, DateTime? lastSyncedAt, String? error}) =>
      SyncState(
        phase: phase ?? this.phase,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        error: error,
      );
}

/// The sync engine, available only when backend credentials are configured.
final syncEngineProvider = Provider<SyncEngine?>((ref) {
  if (!Env.hasBackend) return null;
  return SyncEngine(
    db: ref.watch(databaseProvider),
    remote: SupabaseSyncRemote(Supabase.instance.client),
    settings: ref.watch(settingsRepositoryProvider),
    shopId: ref.watch(shopIdProvider),
  );
});

final syncControllerProvider =
    StateNotifierProvider<SyncController, SyncState>((ref) {
  return SyncController(ref);
});

class SyncController extends StateNotifier<SyncState> {
  SyncController(this._ref)
      : super(SyncState(
            phase: Env.hasBackend ? SyncPhase.idle : SyncPhase.disabled)) {
    if (Env.hasBackend) _init();
  }

  final Ref _ref;
  StreamSubscription? _connSub;
  Timer? _periodic;
  bool _running = false;

  Future<void> _init() async {
    // Establish an auth session. Anonymous for now; Phase 5 replaces this with
    // a license-bound session carrying the shop_id claim.
    await _ensureSession();

    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) sync();
    });
    // Safety-net periodic sync every 5 minutes.
    _periodic = Timer.periodic(const Duration(minutes: 5), (_) => sync());

    unawaited(sync());
  }

  Future<void> _ensureSession() async {
    try {
      final auth = Supabase.instance.client.auth;
      if (auth.currentSession == null) {
        await auth.signInAnonymously();
      }
    } catch (_) {
      // Auth may be unavailable offline; sync() will retry.
    }
  }

  Future<void> sync() async {
    final engine = _ref.read(syncEngineProvider);
    if (engine == null || _running) return;
    _running = true;
    state = state.copyWith(phase: SyncPhase.syncing, error: null);
    try {
      if (Supabase.instance.client.auth.currentSession == null) {
        await _ensureSession();
      }
      await engine.syncNow();
      state = state.copyWith(
          phase: SyncPhase.idle, lastSyncedAt: DateTime.now(), error: null);
    } catch (e) {
      state = state.copyWith(phase: SyncPhase.error, error: e.toString());
    } finally {
      _running = false;
    }
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _periodic?.cancel();
    super.dispose();
  }
}
