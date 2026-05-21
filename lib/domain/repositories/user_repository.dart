import '../../data/databases/app_database.dart';

abstract class UserRepository {
  Future<User?> authenticate(String email, String password);
  Future<void> register(User user, String password);
  Future<User?> getCurrentUser();
  Future<void> updateProfile(User user);
  Future<List<User>> getEmployees();
  Future<bool> hasPermission(User user, String permission);
  Future<void> logout();
  Future<void> logAuditAction(String action, String details);
  Future<List<AuditLogEntry>> getAuditLogs();
}
