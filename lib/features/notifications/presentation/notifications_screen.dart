import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/utils/time_ago.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/user_avatar.dart';
import '../domain/app_notification.dart';
import 'notification_providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        ref.read(notificationsProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _open(AppNotification n) async {
    final ctrl = ref.read(notificationsProvider.notifier);
    final badge = ref.read(notificationBadgeProvider.notifier);
    try {
      await ctrl.markRead(n);
      badge.refresh();
    } catch (_) {/* navigating matters more than the read flag */}
    if (!mounted) return;
    switch (n.type) {
      case 'like':
      case 'comment':
        if (n.postId != null) context.push(Routes.post(n.postId!));
      case 'follow':
        if (n.actorUsername != null) context.push(Routes.user(n.actorUsername!));
      case 'community_request':
      case 'community_added':
      case 'community_approved':
        if (n.communityId != null) context.push(Routes.community(n.communityId!));
    }
  }

  Future<void> _markAll() async {
    try {
      await ref.read(notificationsProvider.notifier).markAllRead();
      ref.read(notificationBadgeProvider.notifier).refresh();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);
    final ctrl = ref.read(notificationsProvider.notifier);
    final hasUnread = state.items.any((n) => !n.isRead);

    Widget body;
    if (state.isLoading) {
      body = const LoadingView();
    } else if (state.error != null && state.items.isEmpty) {
      body = ErrorView(message: state.error!, onRetry: ctrl.refresh);
    } else if (state.items.isEmpty) {
      body = RefreshIndicator(
        onRefresh: ctrl.refresh,
        child: ListView(children: const [
          SizedBox(height: 100),
          EmptyView(
            icon: Icons.notifications_none,
            title: "You're all caught up",
            subtitle: 'Likes, comments, follows and community updates show up here.',
          ),
        ]),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: ctrl.refresh,
        child: ListView.builder(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: state.items.length + 1,
          itemBuilder: (_, i) {
            if (i < state.items.length) {
              final n = state.items[i];
              return _NotificationTile(notification: n, onTap: () => _open(n));
            }
            if (state.isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            if (state.error != null) {
              return TextButton(onPressed: ctrl.loadMore, child: const Text('Tap to retry'));
            }
            return const SizedBox(height: 24);
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (hasUnread) TextButton(onPressed: _markAll, child: const Text('Mark all read')),
        ],
      ),
      body: body,
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});
  final AppNotification notification;
  final VoidCallback onTap;

  static IconData _icon(String type) => switch (type) {
        'like' => Icons.favorite,
        'comment' => Icons.chat_bubble,
        'follow' => Icons.person_add,
        'role_change' => Icons.shield,
        'system' => Icons.campaign,
        _ => Icons.groups,
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final n = notification;
    final unread = !n.isRead;

    final sentence = n.startsWithActor
        ? TextSpan(children: [
            TextSpan(text: n.actorName, style: const TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(text: ' ${n.body}'),
          ])
        : TextSpan(text: n.body);

    return Material(
      color: unread ? t.colorScheme.primary.withValues(alpha: 0.08) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  n.actorId != null
                      ? UserAvatar(url: n.actorAvatarUrl, radius: 22)
                      : CircleAvatar(
                          radius: 22,
                          backgroundColor: t.colorScheme.surfaceContainerHighest,
                          child: Icon(_icon(n.type), color: t.colorScheme.primary),
                        ),
                  if (n.actorId != null)
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: t.scaffoldBackgroundColor,
                        child: Icon(_icon(n.type), size: 13, color: t.colorScheme.primary),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(sentence, style: const TextStyle(height: 1.3)),
                    if ((n.type == 'like' || n.type == 'comment') &&
                        n.postSnippet != null &&
                        n.postSnippet!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(n.postSnippet!.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: t.hintColor, fontSize: 13)),
                    ],
                    const SizedBox(height: 4),
                    Text(timeAgo(n.createdAt), style: TextStyle(color: t.hintColor, fontSize: 12)),
                  ],
                ),
              ),
              if (unread)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 6),
                  child: CircleAvatar(radius: 5, backgroundColor: t.colorScheme.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
