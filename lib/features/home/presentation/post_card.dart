import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_ago.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../reports/presentation/report_sheet.dart';
import '../domain/post.dart';
import 'post_media_grid.dart';

class PostCard extends ConsumerWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onDelete,
    this.onOpen,
    this.canModerate = false,
  });

  final Post post;
  final VoidCallback onLike;
  final VoidCallback onDelete;
  final VoidCallback? onOpen;
  final bool canModerate; // e.g. community moderators

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) onDelete();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final isMine = ref.watch(authControllerProvider.select((a) => a.profile?.id)) == post.authorId;

    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => context.push(Routes.user(post.username)),
                  child: UserAvatar(url: post.avatarUrl, radius: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.push(Routes.user(post.username)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('@${post.username} · ${timeAgo(post.createdAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: t.hintColor, fontSize: 12.5)),
                        if (post.communityName != null)
                          Text('in ${post.communityName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.grass,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) => v == 'report'
                      ? showReportSheet(context, targetType: 'post', targetId: post.id)
                      : _confirmDelete(context),
                  itemBuilder: (_) => [
                    if (isMine || canModerate)
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    if (!isMine) const PopupMenuItem(value: 'report', child: Text('Report')),
                  ],
                ),
              ],
            ),
            if (post.content.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(post.content, style: const TextStyle(height: 1.35)),
              ),
            ],
            if (post.media.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: PostMediaGrid(media: post.media),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onLike,
                  style: TextButton.styleFrom(
                    foregroundColor: post.likedByMe ? AppColors.redstone : t.hintColor,
                  ),
                  icon: Icon(post.likedByMe ? Icons.favorite : Icons.favorite_border, size: 20),
                  label: Text('${post.likesCount}'),
                ),
                TextButton.icon(
                  onPressed: onOpen,
                  style: TextButton.styleFrom(foregroundColor: t.hintColor),
                  icon: const Icon(Icons.chat_bubble_outline, size: 19),
                  label: Text('${post.commentsCount}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
