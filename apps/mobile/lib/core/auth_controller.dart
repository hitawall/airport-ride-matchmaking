import "package:flutter_riverpod/flutter_riverpod.dart";
import "api_client.dart";
import "secure_storage.dart";

class AuthState {
  const AuthState({this.token, this.userId, this.isLoading = true});

  final String? token;
  final String? userId;
  final bool isLoading;

  bool get isAuthenticated => token != null;
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._storage) : super(const AuthState()) {
    _restore();
  }

  final SecureStorage _storage;

  Future<void> _restore() async {
    final session = await _storage.readSession();
    state = session == null
        ? const AuthState(isLoading: false)
        : AuthState(token: session.$1, userId: session.$2, isLoading: false);
  }

  Future<void> login(String token, String userId) async {
    await _storage.saveSession(token, userId);
    state = AuthState(token: token, userId: userId, isLoading: false);
  }

  Future<void> logout() async {
    await _storage.clearSession();
    state = const AuthState(isLoading: false);
  }
}

final secureStorageProvider = Provider((ref) => const SecureStorage());

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref.watch(secureStorageProvider)),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  final auth = ref.watch(authControllerProvider);
  return ApiClient(token: auth.token);
});

/// Carries the phone number collected on the signup screen through to
/// profile setup. Deliberately NOT passed via GoRouter's `extra` for that
/// hop -- `login()` changes auth state, which rebuilds `appRouterProvider`
/// (it watches `authControllerProvider`) into a brand new `GoRouter`
/// instance, and that swap can race with and drop an in-flight `.go()`'s
/// extra. A plain provider isn't affected by the router being recreated.
final pendingSignupPhoneNumberProvider = StateProvider<String?>((ref) => null);
