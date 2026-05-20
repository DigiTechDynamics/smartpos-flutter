import '../../domain/repositories/sync_repository.dart';
import '../databases/app_database.dart';
import 'package:drift/drift.dart';

class SyncRepositoryImpl implements SyncRepository {
  final AppDatabase db;
  SyncRepositoryImpl(this.db);

  @override
  Future<void> queueSyncAction(String tableName, String recordId, String action) async {
    await db.into(db.syncQueue).insert(
      SyncQueueCompanion.insert(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        targetTable: tableName,
        recordId: recordId,
        action: action,
      )
    );
  }

  @override
  Future<void> processSyncQueue() async {
    // Read queue, post to API, mark as synced
    final pending = await (db.select(db.syncQueue)
      ..where((tbl) => tbl.status.equals('pending')))
      .get();
      
    for (var item in pending) {
      // Simulate sync
      await db.update(db.syncQueue).replace(
        item.copyWith(status: 'synced')
      );
    }
  }

  @override
  Future<bool> resolveConflict(String tableName, String recordId, Map<String, dynamic> remoteData) async {
    return true;
  }
}
