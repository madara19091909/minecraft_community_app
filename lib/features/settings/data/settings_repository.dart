import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/user_settings.dart';

class BlockedUser {
  const BlockedUser({required this.userId, required this.username, required this.displayName, this.avatarUrl});
  final String userId;
  final String username;
  final String displayName;
  final String? avatarUrl;

  factory BlockedUser.fromMap(Map<String, dynamic> m) {
    final n = (m['display_name'] as String?)?.trim();
    return BlockedUser(
      userId: m['user_id'] as String,
      username: m['username'] as String,
      displayName: (n == null || n.isEmpty) ? m['username'] as String : n,
      avatarUrl: m['avatar_url'] as String?,
    );
  }
}

class SettingsRepository {
  SettingsRepository([SupabaseClient? client]) : _client = client ?? SupabaseService.client;
  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;
  String? get email => _client.auth.currentUser?.email;
  String? get lastSignInAt => _client.auth.currentUser?.lastSignInAt;

  Future<UserSettings> fetch() async {
    final uid = currentUserId;
    if (uid == null) return const UserSettings();
    try {
      final row = await _client.from('user_settings').select().eq('user_id', uid).maybeSingle();
      return row == null ? const UserSettings() : UserSettings.fromMap(row);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> save(UserSettings s) async {
    try {
      await _client.from('user_settings').upsert(s.toMap(_client.auth.currentUser!.id));
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<List<BlockedUser>> fetchBlocked() async {
    try {
      final rows = await _client
          .from('blocked_user_details')
          .select()
          .order('created_at', ascending: false);
      return [for (final r in rows) BlockedUser.fromMap(r)];
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> block(String userId) async {
    try {
      await _client.rpc('block_user', params: {'p_user': userId});
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> unblock(String userId) async {
    try {
      await _client
          .from('user_blocks')
          .delete()
          .eq('blocker_id', _client.auth.currentUser!.id)
          .eq('blocked_id', userId);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> updateEmail(String email) async {
    try {
      await _client.auth.updateUser(UserAttributes(email: email.trim()));
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> updatePassword(String password) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: password));
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> signOut(SignOutScope scope) async {
    try {
      await _client.auth.signOut(scope: scope);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }
}
