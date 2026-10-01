import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/time_ago.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../reports/presentation/report_sheet.dart';
import '../domain/comment.dart';
import '../domain/post.dart';
import 'post_card.dart';
import 'post_providers.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId});
  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _input = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _toast(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppFailure.from(e).message)));
    }
  }

  void _bumpCounts(int delta) {
    ref.read(feedProvider.notifier).patch(
        widget.postId, (p) => p.copyWith(commentsCount: (p.commentsCount + delta).clamp(0, 1 << 30)));
    ref.invalidate(postDetailProvider(widget.postId));
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final c = await ref.read(postRepositoryProvider).addComment(widget.postId, text);
      ref.read(commentsProvider(widget.postId).notifier).append(c);
      _bumpCounts(1);
      _input.clear();
    } catch (e) {
      _toast(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteComment(Comment c) async {
    try {
      await ref.read(postRepositoryProvider).deleteComment(c.id);
      ref.read(commentsProvider(widget.postId).notifier).remove(c.id);
      _bumpCounts(-1);
    } catch (e) {
      _toast(e);
    }
  }

  Future<void> _like(Post post) async {
    try {
      await ref.read(feedProvider.notifier).toggleLike(post);
    } catch (e) {
      _toast(e);
    }
    ref.invalidate(postDetailProvider(widget.postId));
  }

  Future<void> _deletePost(Post post) async {
    try {
      await ref.read(feedProvider.notifier).deletePost(post);
      if (mounted) context.pop();
    } catch (e) {
      _toast(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(postDetailProvider(widget.postId));
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: postAsync.when(
        skipLoadingOnReload: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: AppFailure.from(e).message,
          onRetry: () => ref.invalidate(postDetailProvider(widget.postId)),
        ),
        data: (post) => post == null
            ? const EmptyView(icon: Icons.search_off, title: 'Post not found')
            : Column(
                children: [
                  Expanded(child: _Thread(post: post, onLike: _like, onDelete: _deletePost, onDeleteComment: _deleteComment)),
                  _CommentInput(controller: _input, sending: _sending, onSend: _send),
                ],
              ),
      ),
    );
  }
}

class _Thread extends ConsumerWidget {
  const _Thread({
    required this.post,
    required this.onLike,
    required this.onDelete,
    required this.onDeleteComment,
  });
  final Post post;
  final Future<void> Function(Post) onLike;
  final Future<void> Function(Post) onDelete;
  final Future<void> Function(Comment) onDeleteComment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comments = ref.watch(commentsProvider(post.id));
    final notifier = ref.read(commentsProvider(post.id).notifier);
    final myId = ref.watch(authControllerProvider.select((a) => a.profile?.id));

    return ListView(
      children: [
        PostCard(post: post, onLike: () => onLike(post), onDelete: () => onDelete(post)),
        const Divider(height: 1),
        if (comments.isLoading)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else if (comments.error != null && comments.items.isEmpty)
          ErrorView(message: comments.error!, onRetry: notifier.refresh)
        else if (comments.items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text('No comments yet', style: TextStyle(color: Theme.of(context).hintColor)),
            ),
          )
        else ...[
          for (final c in comments.items)
            _CommentTile(comment: c, isMine: c.authorId == myId, onDelete: () => onDeleteComment(c)),
          if (comments.isLoadingMore)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          else if (comments.hasMore)
            TextButton(onPressed: notifier.loadMore, child: const Text('Load more comments')),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.isMine, required this.onDelete});
  final Comment comment;
  final bool isMine;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 4, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.push(Routes.user(comment.username)),
            child: UserAvatar(url: comment.avatarUrl, radius: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: comment.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(
                    text: '  ${timeAgo(comment.createdAt)}',
                    style: TextStyle(color: t.hintColor, fontSize: 12),
                  ),
                ])),
                const SizedBox(height: 2),
                Text(comment.content, style: const TextStyle(height: 1.3)),
              ],
            ),
          ),
          if (isMine)
            IconButton(
              tooltip: 'Delete',
              icon: Icon(Icons.delete_outline, size: 20, color: t.hintColor),
              onPressed: onDelete,
            )
          else
            IconButton(
              tooltip: 'Report',
              icon: Icon(Icons.flag_outlined, size: 20, color: t.hintColor),
              onPressed: () => showReportSheet(context, targetType: 'comment', targetId: comment.id),
            ),
        ],
      ),
    );
  }
}

class _CommentInput extends StatelessWidget {
  const _CommentInput({required this.controller, required this.sending, required this.onSend});
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Add a comment…', counterText: ''),
              ),
            ),
            IconButton(
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
