import '../../domain/repositories/user_repository.dart';
import '../databases/app_database.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class UserRepositoryImpl implements UserRepository {
  final AppDatabase db;
  final SharedPreferences prefs;
  
  UserRepositoryImpl(this.db, this.prefs);

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  @override
  Future<User?> authenticate(String email, String password) async {
    final hashedPassword = _hashPassword(password);
    final query = db.select(db.users)
      ..where((tbl) => tbl.email.equals(email) & tbl.passwordHash.equals(hashedPassword));
    final user = await query.getSingleOrNull();
    if (user != null) {
      if (!user.isActive) {
        await logAuditAction('login_blocked', 'Inactive user ${user.email} attempted to log in.');
        return null;
      }
      await prefs.setString('current_user_id', user.id);
      await logAuditAction('login', 'User ${user.email} successfully logged in.');
    } else {
      // Create a temporary audit trail for failed logins
      final uuid = DateTime.now().millisecondsSinceEpoch.toString();
      await db.into(db.auditLog).insert(
        AuditLogEntry(
          id: '${uuid}_failed_login',
          userId: 'guest',
          action: 'login_failed',
          details: 'Failed login attempt for email: $email.',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          syncStatus: 'pending',
        ),
      );
    }
    return user;
  }

  @override
  Future<void> register(User user, String password) async {
    final hashedPassword = _hashPassword(password);
    final userToInsert = user.copyWith(passwordHash: hashedPassword);
    await db.into(db.users).insert(userToInsert);
    await logAuditAction('user_registered', 'Registered new user: ${user.email} with role: ${user.role}.');
  }

  @override
  Future<User?> getCurrentUser() async {
    final id = prefs.getString('current_user_id');
    if (id == null) return null;
    final query = db.select(db.users)..where((tbl) => tbl.id.equals(id));
    return await query.getSingleOrNull();
  }

  @override
  Future<void> updateProfile(User user) async {
    await db.update(db.users).replace(user);
    await logAuditAction('user_updated', 'Updated user: ${user.email}, role: ${user.role}, active: ${user.isActive}.');
  }

  @override
  Future<List<User>> getEmployees() async {
    return await db.select(db.users).get();
  }

  @override
  Future<bool> hasPermission(User user, String permission) async {
    // Basic RBAC
    if (user.role == 'admin') return true;
    if (user.role == 'manager') {
      // Managers can adjust stock and view reports but not manage users
      if (permission == 'user_management') return false;
      return true;
    }
    // Cashiers only have POS checkout
    if (user.role == 'cashier') {
      if (permission == 'checkout') return true;
      return false;
    }
    return false;
  }

  @override
  Future<void> logout() async {
    final currentUser = await getCurrentUser();
    if (currentUser != null) {
      await logAuditAction('logout', 'User ${currentUser.email} logged out.');
    }
    await prefs.remove('current_user_id');
  }

  @override
  Future<void> logAuditAction(String action, String details) async {
    final currentUser = await getCurrentUser();
    final userId = currentUser?.id ?? 'unknown_user';
    final uuid = DateTime.now().millisecondsSinceEpoch.toString() + '_' + userId.hashCode.toString();
    
    await db.into(db.auditLog).insert(
      AuditLogEntry(
        id: uuid,
        userId: userId,
        action: action,
        details: details,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        syncStatus: 'pending',
      ),
    );
  }

  @override
  Future<List<AuditLogEntry>> getAuditLogs() async {
    final query = db.select(db.auditLog)
      ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)]);
    return await query.get();
  }
}
