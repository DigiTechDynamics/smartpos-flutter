import '../../domain/repositories/settings_repository.dart';
import '../databases/app_database.dart';
import 'package:drift/drift.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final AppDatabase db;
  
  SettingsRepositoryImpl(this.db);

  @override
  Future<String?> getSetting(String key) async {
    final query = db.select(db.settings)..where((tbl) => tbl.key.equals(key));
    final result = await query.getSingleOrNull();
    return result?.value;
  }

  @override
  Future<void> saveSetting(String key, String value) async {
    await db.into(db.settings).insertOnConflictUpdate(
      Setting(key: key, value: value),
    );
  }

  @override
  Future<Map<String, String>> getAllSettings() async {
    final result = await db.select(db.settings).get();
    return {for (var setting in result) setting.key: setting.value};
  }
}
