import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../notifications/presentation/notification_providers.dart';
import 'post_card.dart';
import 'post_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
        ref.read(feedProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _toast(Object e) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(AppFailure.from(e).message)));

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedProvider);
    final ctrl = ref.read(feedProvider.notifier);

    Widget body;
    if (feed.isLoading) {
      body = const LoadingView();
    } else if (feed.error != null && feed.items.isEmpty) {
      body = ErrorView(message: feed.error!, onRetry: ctrl.refresh);
    } else if (feed.items.isEmpty) {
      body = RefreshIndicator(
        onRefresh: ctrl.refresh,
        child: ListView(children: const [
          SizedBox(height: 120),
          EmptyView(
            icon: Icons.dynamic_feed,
            title: 'Nothing here yet',
            subtitle: 'Be the first to post something.',
          ),
        ]),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: ctrl.refresh,
        child: ListView.separated(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: feed.items.length + 1,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            if (i == feed.items.length) return _Footer(state: feed, onRetry: ctrl.loadMore);
            final post = feed.items[i];
            return PostCard(
              key: ValueKey(post.id),
              post: post,
              onOpen: () => context.push(Routes.post(post.id)),
              onLike: () => ctrl.toggleLike(post).catchError(_toast),
              onDelete: () => ctrl.deletePost(post).catchError(_toast),
            );
          },
        ),
      );
    }

    final unread = ref.watch(notificationBadgeProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blockverse'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: Badge.count(
              count: unread,
              isLabelVisible: unread > 0,
              child: const Icon(Icons.notifications_none),
            ),
            onPressed: () => context.push(Routes.notifications),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state, required this.onRetry});
  final dynamic state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingMore as bool) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (state.error != null) {
      return TextButton(onPressed: onRetry, child: const Text("Couldn't load more. Tap to retry"));
    }
    if (!(state.hasMore as bool)) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text("You're all caught up",
              style: TextStyle(color: Theme.of(context).hintColor)),
        ),
      );
    }
    return const SizedBox(height: 40);
  }
}
