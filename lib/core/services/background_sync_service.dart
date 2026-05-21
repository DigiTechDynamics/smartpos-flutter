import 'package:workmanager/workmanager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'service_locator.dart';
import 'sync_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Check connectivity before syncing
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        debugPrint('Background sync skipped: No internet connection');
        return Future.value(true);
      }

      // Initialize dependencies (since it's a headless isolate)
      await initServiceLocator();
      
      final syncService = sl<SyncService>();
      await syncService.syncAll();
      
      debugPrint('Background sync completed successfully');
      return Future.value(true);
    } catch (err) {
      debugPrint('Background sync failed: $err');
      return Future.value(false); // Returning false indicates retry may be needed
    }
  });
}

class BackgroundSyncService {
  static const String _syncTaskName = "com.smartpos.syncDataTask";

  Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode, // Set to true to see logs in debug mode
    );
  }

  void registerPeriodicSync() {
    Workmanager().registerPeriodicTask(
      "1", 
      _syncTaskName,
      frequency: const Duration(minutes: 15), // Minimum is 15 mins on Android
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }
}
