import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../home/presentation/post_card.dart';
import '../../reports/presentation/report_sheet.dart';
import '../domain/community.dart';
import 'community_avatar.dart';
import 'community_providers.dart';

class CommunityDetailScreen extends ConsumerStatefulWidget {
  const CommunityDetailScreen({super.key, required this.communityId});
  final String communityId;

  @override
  ConsumerState<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends ConsumerState<CommunityDetailScreen> {
  final _scroll = ScrollController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
        final c = ref.read(communityProvider(widget.communityId)).valueOrNull;
        if (c != null && c.canView) {
          ref.read(communityFeedProvider(widget.communityId).notifier).loadMore();
        }
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      refreshCommunityData(ref, widget.communityId);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave(Community c) async {
    final ok = await confirmDialog(
      context,
      title: c.isPending ? 'Cancel request?' : 'Leave ${c.name}?',
      message: c.isPrivate && !c.isPending
          ? 'You will need approval to join again.'
          : 'You can rejoin any time.',
      confirmLabel: c.isPending ? 'Cancel request' : 'Leave',
    );
    if (ok) await _run(() => ref.read(communityRepositoryProvider).leave(c.id));
  }

  Future<void> _delete(Community c) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete community?',
      message: 'All of its posts will be deleted too. This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await ref.read(communityRepositoryProvider).delete(c.id);
      ref.invalidate(myCommunitiesProvider);
      ref.invalidate(discoverProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showErrorSnack(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(communityProvider(widget.communityId));
    final c = async.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(c?.name ?? 'Community'),
        actions: [
          if (c != null && c.canView)
            IconButton(
              tooltip: 'Members',
              icon: const Icon(Icons.people_outline),
              onPressed: () => context.push(Routes.communityMembers(c.id)),
            ),
          if (c != null && (c.canManage || !c.isOwner))
            PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'edit':
                    context.push(Routes.editCommunity(c.id));
                  case 'delete':
                    _delete(c);
                  case 'report':
                    showReportSheet(context, targetType: 'community', targetId: c.id);
                }
              },
              itemBuilder: (_) => [
                if (c.canManage) const PopupMenuItem(value: 'edit', child: Text('Edit community')),
                if (c.isOwner) const PopupMenuItem(value: 'delete', child: Text('Delete community')),
                if (!c.isOwner) const PopupMenuItem(value: 'report', child: Text('Report community')),
              ],
            ),
        ],
      ),
      body: async.when(
        skipLoadingOnReload: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: AppFailure.from(e).message,
          onRetry: () => ref.invalidate(communityProvider(widget.communityId)),
        ),
        data: (c) => c == null
            ? const EmptyView(icon: Icons.search_off, title: 'Community not found')
            : RefreshIndicator(
                onRefresh: () async {
                  refreshCommunityData(ref, c.id);
                  if (c.canView) {
                    await ref.read(communityFeedProvider(c.id).notifier).refresh();
                  }
                },
                child: _Content(
                  community: c,
                  scroll: _scroll,
                  busy: _busy,
                  onJoin: () => _run(() => ref.read(communityRepositoryProvider).join(c)),
                  onLeave: () => _leave(c),
                ),
              ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({
    required this.community,
    required this.scroll,
    required this.busy,
    required this.onJoin,
    required this.onLeave,
  });
  final Community community;
  final ScrollController scroll;
  final bool busy;
  final VoidCallback onJoin;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = community;
    final header = _Header(community: c, busy: busy, onJoin: onJoin, onLeave: onLeave);

    if (!c.canView) {
      return ListView(
        controller: scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          header,
          const SizedBox(height: 40),
          const EmptyView(
            icon: Icons.lock_outline,
            title: 'Private community',
            subtitle: 'Posts and members are visible after the admins approve your request.',
          ),
        ],
      );
    }

    final feed = ref.watch(communityFeedProvider(c.id));
    final ctrl = ref.read(communityFeedProvider(c.id).notifier);

    return ListView.builder(
      controller: scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: 2 + feed.items.length,
      itemBuilder: (context, i) {
        if (i == 0) return header;
        if (i == 1 + feed.items.length) {
          if (feed.isLoading || feed.isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          if (feed.error != null) {
            return ErrorView(
              message: feed.error!,
              onRetry: feed.items.isEmpty ? ctrl.refresh : ctrl.loadMore,
            );
          }
          if (feed.items.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: EmptyView(
                icon: Icons.dynamic_feed,
                title: 'No posts yet',
                subtitle: 'Members can start the conversation.',
              ),
            );
          }
          return const SizedBox(height: 32);
        }
        final post = feed.items[i - 1];
        return Column(
          children: [
            const Divider(height: 1),
            PostCard(
              key: ValueKey(post.id),
              post: post,
              canModerate: c.canModerate,
              onOpen: () => context.push(Routes.post(post.id)),
              onLike: () => ctrl.toggleLike(post).catchError((e) => showErrorSnack(context, e)),
              onDelete: () => ctrl.deletePost(post).catchError((e) => showErrorSnack(context, e)),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.community,
    required this.busy,
    required this.onJoin,
    required this.onLeave,
  });
  final Community community;
  final bool busy;
  final VoidCallback onJoin;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = community;
    final t = Theme.of(context);
    final bg = t.scaffoldBackgroundColor;

    final Widget action;
    if (busy) {
      action = const SizedBox(height: 44, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    } else if (c.isMember) {
      action = Row(children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
            onPressed: () {
              ref.read(composeCommunityProvider.notifier).state = c.id;
              context.go(Routes.create);
            },
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('New post'),
          ),
        ),
        if (!c.isOwner) ...[
          const SizedBox(width: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(96, 46)),
            onPressed: onLeave,
            child: const Text('Joined'),
          ),
        ],
      ]);
    } else if (c.isPending) {
      action = OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
        onPressed: onLeave,
        child: const Text('Requested · tap to cancel'),
      );
    } else {
      action = FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
        onPressed: onJoin,
        child: Text(c.isPrivate ? 'Request to join' : 'Join'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 150,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0, right: 0, top: 0, height: 110,
                child: c.bannerUrl == null
                    ? const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [AppColors.dirt, AppColors.grassDark]),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: c.bannerUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: 1200,
                        errorWidget: (_, __, ___) => const ColoredBox(color: AppColors.surfaceHighDark),
                      ),
              ),
              Positioned(
                left: 16, bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: CommunityAvatar(url: c.iconUrl, size: 72),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.name, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(c.isPrivate ? Icons.lock : Icons.public, size: 15, color: t.hintColor),
                const SizedBox(width: 5),
                Text(
                  '${c.isPrivate ? 'Private' : 'Public'} · ${c.memberCount} ${c.memberCount == 1 ? 'member' : 'members'}',
                  style: TextStyle(color: t.hintColor),
                ),
              ]),
              if (c.description != null && c.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(c.description!),
              ],
              if (c.rules != null && c.rules!.trim().isNotEmpty)
                Theme(
                  data: t.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    title: const Text('Rules', style: TextStyle(fontWeight: FontWeight.w700)),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(c.rules!)],
                  ),
                ),
              const SizedBox(height: 14),
              action,
            ],
          ),
        ),
      ],
    );
  }
}
