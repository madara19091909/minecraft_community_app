import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/picked_image.dart';
import '../domain/comment.dart';
import '../domain/post.dart';

class PostRepository {
  PostRepository([SupabaseClient? client]) : _client = client ?? SupabaseService.client;
  final SupabaseClient _client;
  static const _bucket = 'post-media';

  String get _uid => _client.auth.currentUser!.id;

  Future<List<Post>> fetchFeed({DateTime? before, String? communityId, int limit = 20}) async {
    try {
      var q = _client.from('feed_posts').select();
      if (communityId != null) q = q.eq('community_id', communityId);
      if (before != null) q = q.lt('created_at', before.toUtc().toIso8601String());
      final rows = await q.order('created_at', ascending: false).limit(limit);
      return [for (final r in rows) Post.fromMap(r)];
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<Post?> fetchPost(String id) async {
    try {
      final row = await _client.from('feed_posts').select().eq('id', id).maybeSingle();
      return row == null ? null : Post.fromMap(row);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> createPost({
    required String content,
    required List<PickedImage> images,
    String? communityId,
  }) async {
    String? postId;
    final uploaded = <String>[];
    try {
      final row = await _client
          .from('posts')
          .insert({
            'author_id': _uid,
            'content': content.trim(),
            if (communityId != null) 'community_id': communityId,
          })
          .select('id')
          .single();
      postId = row['id'] as String;

      final media = <Map<String, dynamic>>[];
      for (var i = 0; i < images.length; i++) {
        final img = images[i];
        final path = '$_uid/$postId/$i.${img.extension}';
        await _client.storage.from(_bucket).uploadBinary(
              path,
              img.bytes,
              fileOptions: FileOptions(contentType: img.contentType),
            );
        uploaded.add(path);
        media.add({
          'post_id': postId,
          'url': _client.storage.from(_bucket).getPublicUrl(path),
          'storage_path': path,
          'kind': 'image',
          'position': i,
        });
      }
      if (media.isNotEmpty) await _client.from('post_media').insert(media);
    } catch (e) {
      // Roll back so a failed upload never leaves a half-published post.
      if (postId != null) {
        try {
          await _client.from('posts').delete().eq('id', postId);
        } catch (_) {}
      }
      if (uploaded.isNotEmpty) {
        try {
          await _client.storage.from(_bucket).remove(uploaded);
        } catch (_) {}
      }
      throw AppFailure.from(e);
    }
  }

  Future<List<Post>> fetchUserPosts(String userId, {int limit = 50}) async {
    try {
      final rows = await _client
          .from('feed_posts')
          .select()
          .eq('author_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      return [for (final r in rows) Post.fromMap(r)];
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<List<Post>> fetchLikedPosts(String userId, {int limit = 50}) async {
    try {
      final likes = await _client
          .from('likes')
          .select('post_id')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      final ids = [for (final row in likes) row['post_id'] as String];
      if (ids.isEmpty) return const [];
      final rows = await _client
          .from('feed_posts')
          .select()
          .inFilter('id', ids)
          .order('created_at', ascending: false)
          .limit(limit);
      return [for (final r in rows) Post.fromMap(r)];
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> deletePost(String id) async {
    try {
      final media = await _client.from('post_media').select('storage_path').eq('post_id', id);
      await _client.from('posts').delete().eq('id', id);
      final paths = [for (final m in media) m['storage_path'] as String];
      if (paths.isNotEmpty) {
        try {
          await _client.storage.from(_bucket).remove(paths);
        } catch (_) {}
      }
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> like(String postId) async {
    try {
      await _client.from('likes').insert({'user_id': _uid, 'post_id': postId});
    } on PostgrestException catch (e) {
      if (e.code == '23505') return;
      throw AppFailure.from(e);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> unlike(String postId) async {
    try {
      await _client.from('likes').delete().eq('user_id', _uid).eq('post_id', postId);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<List<Comment>> fetchComments(String postId, {DateTime? after, int limit = 30}) async {
    try {
      var q = _client.from('comment_details').select().eq('post_id', postId);
      if (after != null) q = q.gt('created_at', after.toUtc().toIso8601String());
      final rows = await q.order('created_at', ascending: true).limit(limit);
      return [for (final r in rows) Comment.fromMap(r)];
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<Comment> addComment(String postId, String content) async {
    try {
      final ins = await _client
          .from('comments')
          .insert({'post_id': postId, 'author_id': _uid, 'content': content.trim()})
          .select('id')
          .single();
      final row = await _client.from('comment_details').select().eq('id', ins['id']).single();
      return Comment.fromMap(row);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> deleteComment(String id) async {
    try {
      await _client.from('comments').delete().eq('id', id);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }
}
