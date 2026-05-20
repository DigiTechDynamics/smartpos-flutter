import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalStorageConstants {
  static const String userData = 'user_data';
  static const String storeSettings = 'store_settings';
  static const String lastSync = 'last_sync';
  static const String printerDevice = 'printer_device';
  static const String appVersion = 'app_version';

  static const String authToken = 'auth_token';
  static const String refreshToken = 'refresh_token';
  static const String dbEncryptionKey = 'db_encryption_key';
}

class LocalStorageService {
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  LocalStorageService(this._prefs) : _secureStorage = const FlutterSecureStorage();

  // Basic Types
  Future<void> saveString(String key, String value) async => await _prefs.setString(key, value);
  String? getString(String key) => _prefs.getString(key);

  Future<void> saveInt(String key, int value) async => await _prefs.setInt(key, value);
  int? getInt(String key) => _prefs.getInt(key);

  Future<void> saveDouble(String key, double value) async => await _prefs.setDouble(key, value);
  double? getDouble(String key) => _prefs.getDouble(key);

  Future<void> saveBool(String key, bool value) async => await _prefs.setBool(key, value);
  bool? getBool(String key) => _prefs.getBool(key);

  // JSON Objects
  Future<void> saveObject<T>(String key, dynamic object) async {
    // We use dynamic for object to rely on jsonEncode finding a toJson() method,
    // or passing an explicit map.
    final jsonString = jsonEncode(object);
    await _prefs.setString(key, jsonString);
  }

  T? getObject<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final jsonString = _prefs.getString(key);
    if (jsonString == null) return null;
    try {
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      return fromJson(jsonMap);
    } catch (e) {
      return null;
    }
  }

  // Secure Storage
  Future<void> saveSecure(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  Future<String?> getSecure(String key) async {
    return await _secureStorage.read(key: key);
  }

  Future<void> removeSecure(String key) async {
    await _secureStorage.delete(key: key);
  }

  // General Methods
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  Future<void> clear() async {
    await _prefs.clear();
    await _secureStorage.deleteAll();
  }

  Set<String> getAllKeys() {
    return _prefs.getKeys();
  }
}
