import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import 'community_providers.dart';
import 'community_tile.dart';

class CommunitiesScreen extends ConsumerWidget {
  const CommunitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canCreate = ref.watch(canCreateCommunityProvider).valueOrNull ?? false;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Communities'),
          actions: [
            if (canCreate)
              IconButton(
                tooltip: 'Create community',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => context.push(Routes.newCommunity),
              ),
          ],
          bottom: const TabBar(tabs: [Tab(text: 'Mine'), Tab(text: 'Discover')]),
        ),
        body: const TabBarView(children: [_MineTab(), _DiscoverTab()]),
      ),
    );
  }
}

class _MineTab extends ConsumerWidget {
  const _MineTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(myCommunitiesProvider).when(
          skipLoadingOnReload: true,
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: AppFailure.from(e).message,
            onRetry: () => ref.invalidate(myCommunitiesProvider),
          ),
          data: (list) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myCommunitiesProvider);
              await ref.read(myCommunitiesProvider.future);
            },
            child: list.isEmpty
                ? ListView(children: const [
                    SizedBox(height: 100),
                    EmptyView(
                      icon: Icons.groups,
                      title: "You haven't joined any community",
                      subtitle: 'Open the Discover tab to find one.',
                    ),
                  ])
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: list.length,
                    itemBuilder: (_, i) => CommunityTile(community: list[i]),
                  ),
          ),
        );
  }
}

class _DiscoverTab extends ConsumerStatefulWidget {
  const _DiscoverTab();

  @override
  ConsumerState<_DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends ConsumerState<_DiscoverTab> {
  final _scroll = ScrollController();
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        ref.read(discoverProvider(_query).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoverProvider(_query));
    final ctrl = ref.read(discoverProvider(_query).notifier);

    Widget list;
    if (state.isLoading) {
      list = const LoadingView();
    } else if (state.error != null && state.items.isEmpty) {
      list = ErrorView(message: state.error!, onRetry: ctrl.refresh);
    } else if (state.items.isEmpty) {
      list = EmptyView(
        icon: Icons.search_off,
        title: _query.isEmpty ? 'No communities yet' : 'No results for "$_query"',
      );
    } else {
      list = RefreshIndicator(
        onRefresh: ctrl.refresh,
        child: ListView.builder(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: state.items.length + 1,
          itemBuilder: (_, i) {
            if (i < state.items.length) return CommunityTile(community: state.items[i]);
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Search communities',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(child: list),
      ],
    );
  }
}
