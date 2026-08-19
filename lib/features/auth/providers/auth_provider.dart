import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmassist/core/utils/hash_utils.dart';
import 'package:pharmassist/data/local/app_database.dart';
import 'package:pharmassist/data/local/database_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthState {
  final User? currentUser;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.currentUser,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isAuthenticated => currentUser != null;
  int? get userId => currentUser?.id;
  String get role => currentUser?.role ?? '';
  String get userName => currentUser?.name ?? '';

  AuthState copyWith({
    User? currentUser,
    bool? isLoading,
    String? errorMessage,
    bool clearUser = false,
  }) {
    return AuthState(
      currentUser: clearUser ? null : (currentUser ?? this.currentUser),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  static const String _kLoggedInUserIdKey = 'logged_in_user_id';
  final AppDatabase _db;

  AuthNotifier(this._db) : super(const AuthState(isLoading: true)) {
    _restoreSavedSession();
  }

  Future<void> _restoreSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getInt(_kLoggedInUserIdKey);

      if (savedUserId != null) {
        final query = _db.select(_db.users)..where((u) => u.id.equals(savedUserId));
        final user = await query.getSingleOrNull();
        if (user != null) {
          state = state.copyWith(currentUser: user, isLoading: false);
          return;
        }
      }
    } catch (_) {}

    state = state.copyWith(isLoading: false);
  }

  Future<bool> loginSingleUser(String pin) async {
    final users = await _db.select(_db.users).get();
    if (users.isEmpty) {
      state = state.copyWith(isLoading: false, errorMessage: 'No user profile found.');
      return false;
    }
    return loginWithPin(users.first.id, pin);
  }

  Future<bool> loginWithPin(int userId, String pin) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final query = _db.select(_db.users)..where((u) => u.id.equals(userId));
      final user = await query.getSingleOrNull();

      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'User not found.',
        );
        return false;
      }

      if (HashUtils.verifyPin(pin, user.pinHash)) {
        // Persist session to SharedPreferences
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(_kLoggedInUserIdKey, user.id);
        } catch (_) {}

        state = state.copyWith(
          currentUser: user,
          isLoading: false,
          errorMessage: null,
        );

        // Log activity
        await _db.into(_db.activityLogs).insert(
          ActivityLogsCompanion.insert(
            userId: user.id,
            action: 'LOGIN',
            entity: 'User',
            entityId: Value(user.id.toString()),
          ),
        );

        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Invalid PIN. Please try again.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Login failed: ${e.toString()}',
      );
      return false;
    }
  }

  Future<void> logout() async {
    if (state.currentUser != null) {
      final userId = state.currentUser!.id;
      try {
        await _db.into(_db.activityLogs).insert(
          ActivityLogsCompanion.insert(
            userId: userId,
            action: 'LOGOUT',
            entity: 'User',
            entityId: Value(userId.toString()),
          ),
        );
      } catch (_) {}
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kLoggedInUserIdKey);
    } catch (_) {}

    state = const AuthState(currentUser: null, isLoading: false, errorMessage: null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final db = ref.watch(databaseProvider);
  return AuthNotifier(db);
});

final allUsersProvider = FutureProvider<List<User>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.select(db.users).get();
});
