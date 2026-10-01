import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/picked_image.dart';
import '../domain/profile_details.dart';

export '../../../core/utils/picked_image.dart';

class ProfileRepository {
  ProfileRepository([SupabaseClient? client]) : _client = client ?? SupabaseService.client;
  final SupabaseClient _client;

  Future<ProfileDetails?> fetchByUsername(String username) async {
    try {
      final row = await _client
          .from('profile_details')
          .select()
          .eq('username', username.toLowerCase())
          .maybeSingle();
      return row == null ? null : ProfileDetails.fromMap(row);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> fields) async {
    try {
      final row = await _client
          .from('profiles')
          .update(fields)
          .eq('id', userId)
          .select('id')
          .maybeSingle();
      if (row == null) throw const AppFailure('Could not save your profile.');
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw const AppFailure('That username is already taken.');
      if (e.code == '23514') throw const AppFailure('One of the values is not valid.');
      throw AppFailure.from(e);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Uploads to `<bucket>/<userId>/<timestamp>.<ext>` (folder = owner, enforced by storage RLS).
  Future<String> uploadImage({
    required String bucket,
    required String userId,
    required PickedImage image,
  }) async {
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.${image.extension}';
    try {
      await _client.storage.from(bucket).uploadBinary(
            path,
            image.bytes,
            fileOptions: FileOptions(contentType: image.contentType, upsert: false),
          );
      return _client.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Best-effort removal of a replaced image. Never throws.
  Future<void> removeImageByUrl(String bucket, String? url) async {
    if (url == null) return;
    final marker = '/object/public/$bucket/';
    final i = url.indexOf(marker);
    if (i < 0) return;
    try {
      await _client.storage.from(bucket).remove([url.substring(i + marker.length)]);
    } catch (_) {}
  }

  Future<void> follow(String targetId) async {
    try {
      await _client.from('follows').insert({
        'follower_id': _client.auth.currentUser!.id,
        'following_id': targetId,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') return; // already following
      throw AppFailure.from(e);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> unfollow(String targetId) async {
    try {
      await _client
          .from('follows')
          .delete()
          .eq('follower_id', _client.auth.currentUser!.id)
          .eq('following_id', targetId);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }
}
