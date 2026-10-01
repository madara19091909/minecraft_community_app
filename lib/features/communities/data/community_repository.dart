import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/picked_image.dart';
import '../domain/community.dart';
import '../domain/community_member.dart';

class CommunityRepository {
  CommunityRepository([SupabaseClient? client]) : _client = client ?? SupabaseService.client;
  final SupabaseClient _client;
  static const _bucket = 'community-media';

  String get _uid => _client.auth.currentUser!.id;

  Future<bool> hasPermission(String key) async {
    try {
      final r = await _client.rpc('has_permission', params: {'p_key': key});
      return r == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Community>> fetchMine() async {
    try {
      final rows = await _client
          .from('community_details')
          .select()
          .eq('my_status', 'active')
          .order('name')
          .limit(200);
      return [for (final r in rows) Community.fromMap(r)];
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<List<Community>> fetchDiscover({String query = '', DateTime? before, int limit = 20}) async {
    try {
      var q = _client.from('community_details').select();
      final term = query.trim().replaceAll('%', r'\%').replaceAll('_', r'\_');
      if (term.isNotEmpty) q = q.ilike('name', '%$term%');
      if (before != null) q = q.lt('created_at', before.toUtc().toIso8601String());
      final rows = await q.order('created_at', ascending: false).limit(limit);
      return [for (final r in rows) Community.fromMap(r)];
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<Community?> fetchById(String id) async {
    try {
      final row = await _client.from('community_details').select().eq('id', id).maybeSingle();
      return row == null ? null : Community.fromMap(row);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<String> _upload(PickedImage img) async {
    final path = '$_uid/${DateTime.now().microsecondsSinceEpoch}.${img.extension}';
    await _client.storage.from(_bucket).uploadBinary(path, img.bytes,
        fileOptions: FileOptions(contentType: img.contentType));
    return _client.storage.from(_bucket).getPublicUrl(path);
  }

  Future<void> _removeByUrl(String? url) async {
    if (url == null) return;
    const marker = '/object/public/$_bucket/';
    final i = url.indexOf(marker);
    if (i < 0) return;
    try {
      await _client.storage.from(_bucket).remove([url.substring(i + marker.length)]);
    } catch (_) {}
  }

  AppFailure _mapWrite(Object e) {
    if (e is PostgrestException && e.code == '23505') {
      return const AppFailure('A community with that name already exists.');
    }
    return AppFailure.from(e);
  }

  Future<String> create({
    required String name,
    String? description,
    String? rules,
    required String privacy,
    PickedImage? icon,
    PickedImage? banner,
  }) async {
    String? iconUrl;
    String? bannerUrl;
    try {
      if (icon != null) iconUrl = await _upload(icon);
      if (banner != null) bannerUrl = await _upload(banner);
      final row = await _client
          .from('communities')
          .insert({
            'name': name.trim(),
            'description': description,
            'rules': rules,
            'privacy': privacy,
            'owner_id': _uid,
            'icon_url': iconUrl,
            'banner_url': bannerUrl,
          })
          .select('id')
          .single();
      return row['id'] as String;
    } catch (e) {
      await _removeByUrl(iconUrl);
      await _removeByUrl(bannerUrl);
      throw _mapWrite(e);
    }
  }

  Future<void> update(
    Community old, {
    required String name,
    String? description,
    String? rules,
    required String privacy,
    PickedImage? icon,
    PickedImage? banner,
  }) async {
    String? iconUrl = old.iconUrl;
    String? bannerUrl = old.bannerUrl;
    try {
      if (icon != null) iconUrl = await _upload(icon);
      if (banner != null) bannerUrl = await _upload(banner);
      final row = await _client
          .from('communities')
          .update({
            'name': name.trim(),
            'description': description,
            'rules': rules,
            'privacy': privacy,
            'icon_url': iconUrl,
            'banner_url': bannerUrl,
          })
          .eq('id', old.id)
          .select('id')
          .maybeSingle();
      if (row == null) throw const AppFailure("You can't edit this community.");
      if (icon != null) await _removeByUrl(old.iconUrl);
      if (banner != null) await _removeByUrl(old.bannerUrl);
    } catch (e) {
      if (icon != null && iconUrl != old.iconUrl) await _removeByUrl(iconUrl);
      if (banner != null && bannerUrl != old.bannerUrl) await _removeByUrl(bannerUrl);
      throw _mapWrite(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      final row = await _client.from('communities').delete().eq('id', id).select('id').maybeSingle();
      if (row == null) throw const AppFailure("You can't delete this community.");
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> join(Community c) async {
    try {
      await _client.from('community_members').insert({
        'community_id': c.id,
        'user_id': _uid,
        'role': 'member',
        'status': c.isPrivate ? 'pending' : 'active',
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') return;
      throw AppFailure.from(e);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Leave a community or cancel a pending request.
  Future<void> leave(String communityId) => removeMember(communityId, _uid);

  Future<void> removeMember(String communityId, String userId) async {
    try {
      await _client
          .from('community_members')
          .delete()
          .eq('community_id', communityId)
          .eq('user_id', userId);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<List<CommunityMember>> fetchMembers(
    String communityId,
    String status, {
    DateTime? after,
    int limit = 50,
  }) async {
    try {
      var q = _client
          .from('community_member_details')
          .select()
          .eq('community_id', communityId)
          .eq('status', status);
      if (after != null) q = q.gt('joined_at', after.toUtc().toIso8601String());
      final rows = await q.order('joined_at', ascending: true).limit(limit);
      return [for (final r in rows) CommunityMember.fromMap(r)];
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> approve(String communityId, String userId) async {
    try {
      final row = await _client
          .from('community_members')
          .update({'status': 'active'})
          .eq('community_id', communityId)
          .eq('user_id', userId)
          .select('user_id')
          .maybeSingle();
      if (row == null) throw const AppFailure('Request no longer exists.');
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> setRole(String communityId, String userId, String role) async {
    try {
      final row = await _client
          .from('community_members')
          .update({'role': role})
          .eq('community_id', communityId)
          .eq('user_id', userId)
          .select('user_id')
          .maybeSingle();
      if (row == null) throw const AppFailure("You can't change this member.");
    } on PostgrestException catch (e) {
      // Messages raised by our DB triggers are already user-readable.
      throw AppFailure(e.code == 'P0001' ? e.message : AppFailure.from(e).message);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> addMember(String communityId, String username) async {
    try {
      final clean = username.trim().toLowerCase().replaceFirst('@', '');
      final prof = await _client.from('profiles').select('id').eq('username', clean).maybeSingle();
      if (prof == null) throw const AppFailure('No user with that username.');
      await _client.from('community_members').insert({
        'community_id': communityId,
        'user_id': prof['id'],
        'role': 'member',
        'status': 'active',
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const AppFailure('Already a member, or has a pending request (approve it instead).');
      }
      throw AppFailure.from(e);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }
}
