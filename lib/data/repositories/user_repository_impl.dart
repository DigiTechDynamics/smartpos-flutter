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
      await prefs.setString('current_user_id', user.id);
    }
    return user;
  }

  @override
  Future<void> register(User user, String password) async {
    final hashedPassword = _hashPassword(password);
    final userToInsert = user.copyWith(passwordHash: hashedPassword);
    await db.into(db.users).insert(userToInsert);
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
  }

  @override
  Future<List<User>> getEmployees() async {
    return await db.select(db.users).get();
  }

  @override
  Future<bool> hasPermission(User user, String permission) async {
    // Basic RBAC
    if (user.role == 'admin') return true;
    return false;
  }

  @override
  Future<void> logout() async {
    await prefs.remove('current_user_id');
  }
}
