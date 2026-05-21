import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:smartpos/presentation/bloc/auth/auth_bloc.dart';
import 'package:smartpos/presentation/bloc/auth/auth_event.dart';
import 'package:smartpos/presentation/bloc/auth/auth_state.dart';
import 'package:smartpos/domain/repositories/user_repository.dart';
import 'package:smartpos/data/databases/app_database.dart';

class MockUserRepository implements UserRepository {
  User? currentUser;
  bool loginShouldFail = false;

  @override
  Future<User?> authenticate(String email, String password) async {
    if (loginShouldFail) throw Exception('Auth error');
    if (email == 'admin@smartpos.com' && password == 'password') {
      currentUser = User(
        id: 'user_admin',
        email: 'admin@smartpos.com',
        role: 'admin',
        passwordHash: 'hashed_password',
        isActive: true,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        syncStatus: 'pending',
      );
      return currentUser;
    }
    return null;
  }

  @override
  Future<void> register(User user, String password) async {}

  @override
  Future<User?> getCurrentUser() async {
    return currentUser;
  }

  @override
  Future<void> updateProfile(User user) async {}

  @override
  Future<List<User>> getEmployees() async => [];

  @override
  Future<bool> hasPermission(User user, String permission) async => true;

  @override
  Future<void> logout() async {
    currentUser = null;
  }

  @override
  Future<void> logAuditAction(String action, String details) async {}

  @override
  Future<List<AuditLogEntry>> getAuditLogs() async => [];
}

void main() {
  late MockUserRepository mockUserRepository;

  setUp(() {
    mockUserRepository = MockUserRepository();
  });

  blocTest<AuthBloc, AuthState>(
    'should emit [AuthLoading, Unauthenticated] when CheckAuthStatusRequested is added and no user is logged in',
    build: () => AuthBloc(mockUserRepository),
    act: (bloc) => bloc.add(CheckAuthStatusRequested()),
    expect: () => [
      isA<AuthLoading>(),
      isA<Unauthenticated>(),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'should emit [AuthLoading, Authenticated] when CheckAuthStatusRequested is added and a user is already logged in',
    build: () => AuthBloc(mockUserRepository),
    setUp: () {
      mockUserRepository.currentUser = User(
        id: 'user_admin',
        email: 'admin@smartpos.com',
        role: 'admin',
        passwordHash: 'hashed_password',
        isActive: true,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        syncStatus: 'pending',
      );
    },
    act: (bloc) => bloc.add(CheckAuthStatusRequested()),
    expect: () => [
      isA<AuthLoading>(),
      isA<Authenticated>(),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'should emit [AuthLoading, Authenticated] when login is successful',
    build: () => AuthBloc(mockUserRepository),
    act: (bloc) => bloc.add(LoginRequested('admin@smartpos.com', 'password')),
    expect: () => [
      isA<AuthLoading>(),
      isA<Authenticated>(),
    ],
    verify: (bloc) {
      final state = bloc.state as Authenticated;
      expect(state.userId, 'user_admin');
    },
  );

  blocTest<AuthBloc, AuthState>(
    'should emit [AuthLoading, AuthError] when credentials are invalid',
    build: () => AuthBloc(mockUserRepository),
    act: (bloc) => bloc.add(LoginRequested('wrong@email.com', 'wrong')),
    expect: () => [
      isA<AuthLoading>(),
      isA<AuthError>(),
    ],
    verify: (bloc) {
      final state = bloc.state as AuthError;
      expect(state.message, 'Invalid credentials');
    },
  );

  blocTest<AuthBloc, AuthState>(
    'should emit [AuthLoading, AuthError] when authenticating throws exception',
    build: () => AuthBloc(mockUserRepository),
    setUp: () => mockUserRepository.loginShouldFail = true,
    act: (bloc) => bloc.add(LoginRequested('admin@smartpos.com', 'password')),
    expect: () => [
      isA<AuthLoading>(),
      isA<AuthError>(),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'should emit [AuthLoading, Unauthenticated] on LogoutRequested',
    build: () => AuthBloc(mockUserRepository),
    act: (bloc) => bloc.add(LogoutRequested()),
    expect: () => [
      isA<AuthLoading>(),
      isA<Unauthenticated>(),
    ],
  );
}
