abstract class SyncRepository {
  Future<void> queueSyncAction(String tableName, String recordId, String action);
  Future<void> processSyncQueue();
  Future<bool> resolveConflict(String tableName, String recordId, Map<String, dynamic> remoteData);
}
