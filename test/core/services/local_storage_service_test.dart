import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smartpos/core/services/local_storage_service.dart';

void main() {
  late LocalStorageService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    
    // We try to test only shared preferences first
    service = LocalStorageService(prefs);
  });

  group('SharedPreferences methods', () {
    test('should save and get String', () async {
      await service.saveString('test_string', 'hello');
      final result = service.getString('test_string');
      expect(result, 'hello');
    });

    test('should save and get Int', () async {
      await service.saveInt('test_int', 42);
      final result = service.getInt('test_int');
      expect(result, 42);
    });

    test('should save and get Double', () async {
      await service.saveDouble('test_double', 3.14);
      final result = service.getDouble('test_double');
      expect(result, 3.14);
    });

    test('should save and get Bool', () async {
      await service.saveBool('test_bool', true);
      final result = service.getBool('test_bool');
      expect(result, isTrue);
    });

    test('should remove key', () async {
      await service.saveString('test_remove', 'to_be_removed');
      await service.remove('test_remove');
      final result = service.getString('test_remove');
      expect(result, isNull);
    });
  });

  group('JSON Objects', () {
    test('should save and get object', () async {
      final mockData = {'id': 1, 'name': 'test_name'};
      await service.saveObject('test_obj', mockData);
      
      final result = service.getObject<Map<String, dynamic>>(
        'test_obj', 
        (json) => json
      );
      
      expect(result, isNotNull);
      expect(result!['id'], 1);
      expect(result['name'], 'test_name');
    });

    test('should return null if getting non-existent object', () {
      final result = service.getObject<Map<String, dynamic>>(
        'non_existent', 
        (json) => json
      );
      expect(result, isNull);
    });
  });
}
