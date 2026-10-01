import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../data/auth_repository.dart';
import '../domain/profile.dart';

enum AuthPhase { loading, signedOut, ready, error }

/// Single source of truth for: session -> profile -> account status.
/// The router listens to this and redirects accordingly.
class AuthController extends ChangeNotifier {
  AuthController(this._repo) {
    _sub = _repo.authChanges.listen((_) => refresh());
    refresh();
  }

  final AuthRepository _repo;
  late final StreamSubscription _sub;

  AuthPhase phase = AuthPhase.loading;
  Profile? profile;
  String? errorMessage;

  bool get canAccessApp => phase == AuthPhase.ready && (profile?.isActive ?? false);

  Future<void> refresh() async {
    if (_repo.currentSession == null) {
      profile = null;
      errorMessage = null;
      _set(AuthPhase.signedOut);
      return;
    }
    if (phase != AuthPhase.ready) _set(AuthPhase.loading);
    try {
      profile = await _repo.fetchMyProfile();
      errorMessage = null;
      _set(AuthPhase.ready);
    } catch (e) {
      // A transient failure while already signed in must not eject the user.
      if (phase == AuthPhase.ready && profile != null) return;
      errorMessage = AppFailure.from(e).message;
      _set(AuthPhase.error);
    }
  }

  /// Silent reload (no loading phase) so the UI is not bounced to the splash screen.
  Future<void> reloadProfile() async {
    try {
      profile = await _repo.fetchMyProfile();
      notifyListeners();
    } catch (_) {
      // Keep the last known profile; a full refresh() will surface real errors.
    }
  }

  Future<void> signIn(String email, String password) =>
      _repo.signIn(email: email, password: password);

  Future<void> signOut() => _repo.signOut();

  void _set(AuthPhase p) {
    phase = p;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((_) => AuthRepository());

final authControllerProvider = ChangeNotifierProvider<AuthController>(
  (ref) => AuthController(ref.watch(authRepositoryProvider)),
);
