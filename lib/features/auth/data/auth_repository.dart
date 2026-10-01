import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/profile.dart';

class AuthRepository {
  AuthRepository([SupabaseClient? client]) : _client = client ?? SupabaseService.client;
  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;
  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(email: email.trim(), password: password);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Returns null when the user has no profile row (not provisioned by admin).
  Future<Profile?> fetchMyProfile() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await _client
          .from('profiles')
          .select('id, username, display_name, avatar_url, status, roles(key)')
          .eq('id', uid)
          .maybeSingle();
      return row == null ? null : Profile.fromMap(row);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }
}
