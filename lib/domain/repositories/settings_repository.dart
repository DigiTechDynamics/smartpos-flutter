import '../../data/databases/app_database.dart';

abstract class SettingsRepository {
  Future<String?> getSetting(String key);
  Future<void> saveSetting(String key, String value);
  Future<Map<String, String>> getAllSettings();
}
