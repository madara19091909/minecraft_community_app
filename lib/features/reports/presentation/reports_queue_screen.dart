import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/utils/time_ago.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/presentation/permission_provider.dart';
import '../domain/report.dart';
import 'report_providers.dart';

class ReportsQueueScreen extends ConsumerStatefulWidget {
  const ReportsQueueScreen({super.key});

  @override
  ConsumerState<ReportsQueueScreen> createState() => _ReportsQueueScreenState();
}

class _ReportsQueueScreenState extends ConsumerState<ReportsQueueScreen> {
  final _scroll = ScrollController();
  String _status = 'pending';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        ref.read(reportsProvider(_status).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  static IconData _icon(String type) => switch (type) {
        'user' => Icons.person,
        'post' => Icons.article,
        'comment' => Icons.chat_bubble,
        'message' => Icons.mail,
        _ => Icons.groups,
      };

  @override
  Widget build(BuildContext context) {
    final allowed = ref.watch(permissionProvider('reports.review'));
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: allowed.when(
        loading: () => const LoadingView(),
        error: (_, __) => const ErrorView(message: 'Could not check permissions.'),
        data: (ok) => !ok ? const ErrorView(message: "You don't have access to this page.") : _body(),
      ),
    );
  }

  Widget _body() {
    final state = ref.watch(reportsProvider(_status));
    final ctrl = ref.read(reportsProvider(_status).notifier);
    final t = Theme.of(context);

    Widget list;
    if (state.isLoading) {
      list = const LoadingView();
    } else if (state.error != null && state.items.isEmpty) {
      list = ErrorView(message: state.error!, onRetry: ctrl.refresh);
    } else if (state.items.isEmpty) {
      list = RefreshIndicator(
        onRefresh: ctrl.refresh,
        child: ListView(children: [
          const SizedBox(height: 100),
          EmptyView(icon: Icons.verified_user_outlined, title: 'No $_status reports'),
        ]),
      );
    } else {
      list = RefreshIndicator(
        onRefresh: ctrl.refresh,
        child: ListView.builder(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: state.items.length + 1,
          itemBuilder: (_, i) {
            if (i == state.items.length) {
              return state.isLoadingMore
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                  : const SizedBox(height: 24);
            }
            final r = state.items[i];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: t.colorScheme.surfaceContainerHighest,
                child: Icon(_icon(r.targetType), color: t.colorScheme.primary, size: 20),
              ),
              title: Text('${r.typeLabel} · ${r.reasonLabel}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                (r.snapshot == null || r.snapshot!.trim().isEmpty)
                    ? 'by @${r.reporterUsername ?? 'unknown'}'
                    : r.snapshot!.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(timeAgo(r.createdAt), style: TextStyle(color: t.hintColor, fontSize: 12)),
              onTap: () => context.push(Routes.report(r.id)),
            );
          },
        ),
      );
    }

    return Column(children: [
      SizedBox(
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          children: [
            for (final s in reportStatuses)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(s[0].toUpperCase() + s.substring(1)),
                  selected: _status == s,
                  onSelected: (_) => setState(() => _status = s),
                ),
              ),
          ],
        ),
      ),
      Expanded(child: list),
    ]);
  }
}
