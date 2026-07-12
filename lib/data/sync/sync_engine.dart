import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/database.dart';
import '../repositories/settings_repository.dart';
import 'sync_mappers.dart';

/// Transport abstraction so the engine can be unit-tested with a fake backend.
abstract class SyncRemote {
  Future<void> upsert(String table, Map<String, dynamic> row);
  Future<void> markDeleted(String table, String id, DateTime updatedAt);

  /// Rows for [shopId] changed strictly after [since] (all rows if null),
  /// ordered by `updated_at` ascending.
  Future<List<Map<String, dynamic>>> fetchChanges(
      String table, String shopId, DateTime? since);
}

/// Supabase-backed transport (PostgREST upsert / filtered select).
class SupabaseSyncRemote implements SyncRemote {
  SupabaseSyncRemote(this._client);
  final SupabaseClient _client;

  @override
  Future<void> upsert(String table, Map<String, dynamic> row) async {
    await _client.from(table).upsert(row);
  }

  @override
  Future<void> markDeleted(String table, String id, DateTime updatedAt) async {
    await _client.from(table).update({
      'is_deleted': true,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    }).eq('id', id);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchChanges(
      String table, String shopId, DateTime? since) async {
    final filter = _client.from(table).select().eq('shop_id', shopId);
    final scoped = since != null
        ? filter.gt('updated_at', since.toUtc().toIso8601String())
        : filter;
    final rows = await scoped.order('updated_at', ascending: true);
    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}

class SyncResult {
  final int pushed;
  final int pulled;
  const SyncResult(this.pushed, this.pulled);
}

/// Drains the outbox to the backend, then pulls remote changes and merges them
/// with last-write-wins. Both directions are resumable: outbox rows are removed
/// only after a successful push, and pull cursors advance per table, so an
/// interrupted sync simply continues next time.
class SyncEngine {
  SyncEngine({
    required this.db,
    required this.remote,
    required this.settings,
    required this.shopId,
    List<SyncTableDef>? tables,
  }) : tables = tables ?? syncTables {
    _byName = {for (final t in this.tables) t.name: t};
  }

  final AppDatabase db;
  final SyncRemote remote;
  final SettingsRepository settings;
  final String shopId;
  final List<SyncTableDef> tables;
  late final Map<String, SyncTableDef> _byName;

  Future<SyncResult> syncNow() async {
    final pushed = await _push();
    final pulled = await _pull();
    return SyncResult(pushed, pulled);
  }

  Future<int> _push() async {
    var count = 0;
    final items = await (db.select(db.outbox)
          ..orderBy([(o) => OrderingTerm(expression: o.seq)]))
        .get();

    for (final item in items) {
      final def = _byName[item.entityTable];
      if (def == null) {
        await _removeOutbox(item.seq);
        continue;
      }
      if (item.op == 'delete') {
        await remote.markDeleted(item.entityTable, item.rowId, DateTime.now());
      } else {
        final row = await def.toRemote(db, item.rowId);
        if (row != null) await remote.upsert(item.entityTable, row);
      }
      await _removeOutbox(item.seq);
      count++;
    }
    return count;
  }

  Future<int> _pull() async {
    var count = 0;
    for (final def in tables) {
      final since = await settings.syncCursor(def.name);
      final changes = await remote.fetchChanges(def.name, shopId, since);

      DateTime? maxSeen = since;
      for (final row in changes) {
        await def.upsertLocal(db, row);
        final u = DateTime.parse(row['updated_at'] as String).toLocal();
        if (maxSeen == null || u.isAfter(maxSeen)) maxSeen = u;
        count++;
      }
      if (maxSeen != null && (since == null || maxSeen.isAfter(since))) {
        await settings.setSyncCursor(def.name, maxSeen);
      }
    }
    return count;
  }

  Future<void> _removeOutbox(int seq) {
    return (db.delete(db.outbox)..where((o) => o.seq.equals(seq))).go();
  }
}
