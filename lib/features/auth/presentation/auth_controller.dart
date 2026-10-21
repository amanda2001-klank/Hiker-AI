import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/auth_repository.dart';
import '../../../../core/api/api_client.dart';

enum AuthStatus { unauthenticated, loading, authenticated, error }

class AuthState {
  final AuthStatus status;
  final UserAuthResponse? user;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  factory AuthState.unauthenticated() => const AuthState(status: AuthStatus.unauthenticated);
  factory AuthState.inLoading() => const AuthState(status: AuthStatus.loading);
  factory AuthState.loggedIn(UserAuthResponse user) => AuthState(status: AuthStatus.authenticated, user: user);
  factory AuthState.failure(String message) => AuthState(status: AuthStatus.error, errorMessage: message);
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final FlutterSecureStorage _secureStorage;
  final ApiClient _apiClient;

  AuthNotifier(this._authRepository, this._secureStorage, this._apiClient) : super(AuthState.unauthenticated()) {
    checkStoredSession();
  }

  Future<void> checkStoredSession() async {
    try {
      final email = await _secureStorage.read(key: 'user_email');
      final username = await _secureStorage.read(key: 'user_username');
      final backendUserId = await _secureStorage.read(key: 'backend_user_id');
      final token = await _secureStorage.read(key: 'auth_token');
      if (email != null && username != null) {
        if (token != null) {
          _apiClient.setAuthToken(token);
        }
        state = AuthState.loggedIn(UserAuthResponse(
          userId: backendUserId ?? 'local_user',
          username: username,
          email: email,
          token: token,
        ));
      }
    } catch (_) {}
  }

  Future<bool> login(String email, String password) async {
    state = AuthState.inLoading();
    try {
      final response = await _authRepository.login(email: email, password: password);
      final user = response.data;
      if (user != null) {
        await _secureStorage.write(key: 'user_email', value: user.email);
        await _secureStorage.write(key: 'user_username', value: user.username);
        if (user.userId.isNotEmpty) {
          await _secureStorage.write(key: 'backend_user_id', value: user.userId);
        }
        if (user.token != null) {
          await _secureStorage.write(key: 'auth_token', value: user.token!);
          _apiClient.setAuthToken(user.token!);
        }
        state = AuthState.loggedIn(user);
        return true;
      } else {
        state = AuthState.failure('Login failed: Invalid response data');
        return false;
      }
    } catch (e) {
      state = AuthState.failure(e.toString());
      return false;
    }
  }

  Future<bool> signup(String email, String password, String username) async {
    state = AuthState.inLoading();
    try {
      final response = await _authRepository.signup(
        email: email,
        password: password,
        username: username,
      );
      final user = response.data;
      if (user != null) {
        await _secureStorage.write(key: 'user_email', value: user.email);
        await _secureStorage.write(key: 'user_username', value: user.username);
        if (user.userId.isNotEmpty) {
          await _secureStorage.write(key: 'backend_user_id', value: user.userId);
        }
        if (user.token != null) {
          await _secureStorage.write(key: 'auth_token', value: user.token!);
          _apiClient.setAuthToken(user.token!);
        }
        state = AuthState.loggedIn(user);
        return true;
      } else {
        state = AuthState.failure('Signup failed: Invalid response data');
        return false;
      }
    } catch (e) {
      state = AuthState.failure(e.toString());
      return false;
    }
  }

  Future<bool> offlineLogin(String email, String username) async {
    state = AuthState.inLoading();
    try {
      final validEmail = email.isNotEmpty ? email : 'user@venture.com';
      final validName = username.isNotEmpty ? username : 'Hiker';
      await _secureStorage.write(key: 'user_email', value: validEmail);
      await _secureStorage.write(key: 'user_username', value: validName);
      await _secureStorage.write(key: 'backend_user_id', value: 'offline_${validEmail.hashCode}');
      state = AuthState.loggedIn(UserAuthResponse(
        userId: 'offline_${validEmail.hashCode}',
        username: validName,
        email: validEmail,
      ));
      return true;
    } catch (e) {
      state = AuthState.failure(e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _secureStorage.delete(key: 'user_email');
      await _secureStorage.delete(key: 'user_username');
      await _secureStorage.delete(key: 'backend_user_id');
      await _secureStorage.delete(key: 'auth_token');
      _apiClient.clearAuthToken();
    } catch (_) {}
    state = AuthState.unauthenticated();
  }
}

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

final authControllerProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  final apiClient = ref.watch(apiClientProvider);
  return AuthNotifier(authRepo, secureStorage, apiClient);
});
