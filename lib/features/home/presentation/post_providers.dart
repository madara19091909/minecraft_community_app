import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/paged.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/post_repository.dart';
import '../domain/comment.dart';
import '../domain/post.dart';

final postRepositoryProvider = Provider<PostRepository>((_) => PostRepository());

class FeedController extends PagedNotifier<Post> {
  FeedController(this._repo, {this.communityId});
  final PostRepository _repo;
  final String? communityId; // null = global feed

  @override
  Future<List<Post>> fetchPage(Post? last) =>
      _repo.fetchFeed(before: last?.createdAt, communityId: communityId, limit: pageSize);

  void patch(String id, Post Function(Post) fn) =>
      mutate((l) => [for (final p in l) p.id == id ? fn(p) : p]);

  /// Optimistic like; reverts and rethrows on failure.
  Future<void> toggleLike(Post post) async {
    final liked = !post.likedByMe;
    patch(post.id, (p) => p.copyWith(likedByMe: liked, likesCount: p.likesCount + (liked ? 1 : -1)));
    try {
      liked ? await _repo.like(post.id) : await _repo.unlike(post.id);
    } catch (_) {
      patch(post.id, (p) => p.copyWith(likedByMe: post.likedByMe, likesCount: post.likesCount));
      rethrow;
    }
  }

  Future<void> deletePost(Post post) async {
    await _repo.deletePost(post.id);
    mutate((l) => l.where((p) => p.id != post.id).toList());
  }
}

/// Rebuilt (and therefore reset) whenever the signed-in user changes.
final feedProvider = StateNotifierProvider<FeedController, PagedState<Post>>((ref) {
  ref.watch(authControllerProvider.select((a) => a.profile?.id));
  return FeedController(ref.watch(postRepositoryProvider));
});

final postDetailProvider = FutureProvider.autoDispose.family<Post?, String>(
  (ref, id) => ref.watch(postRepositoryProvider).fetchPost(id),
);

class CommentsController extends PagedNotifier<Comment> {
  CommentsController(this._repo, this._postId);
  final PostRepository _repo;
  final String _postId;

  @override
  int get pageSize => 30;

  @override
  Future<List<Comment>> fetchPage(Comment? last) =>
      _repo.fetchComments(_postId, after: last?.createdAt, limit: pageSize);

  void append(Comment c) => mutate((l) => [...l, c]);
  void remove(String id) => mutate((l) => l.where((c) => c.id != id).toList());
}

final commentsProvider = StateNotifierProvider.autoDispose
    .family<CommentsController, PagedState<Comment>, String>(
  (ref, postId) => CommentsController(ref.watch(postRepositoryProvider), postId),
);
