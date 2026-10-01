import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/utils/time_ago.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/conversation_summary.dart';
import 'message_providers.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        ref.read(inboxProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(inboxProvider);
    final ctrl = ref.read(inboxProvider.notifier);
    final myId = ref.watch(authControllerProvider.select((a) => a.profile?.id));

    Widget body;
    if (inbox.isLoading) {
      body = const LoadingView();
    } else if (inbox.error != null && inbox.items.isEmpty) {
      body = ErrorView(message: inbox.error!, onRetry: ctrl.refresh);
    } else if (inbox.items.isEmpty) {
      body = RefreshIndicator(
        onRefresh: ctrl.refresh,
        child: ListView(children: const [
          SizedBox(height: 100),
          EmptyView(
            icon: Icons.chat_bubble_outline,
            title: 'No conversations yet',
            subtitle: 'Tap the pencil to start a chat or create a group.',
          ),
        ]),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: ctrl.refresh,
        child: ListView.builder(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: inbox.items.length + 1,
          itemBuilder: (_, i) {
            if (i < inbox.items.length) {
              return _ConversationTile(summary: inbox.items[i], myId: myId);
            }
            if (inbox.isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            return const SizedBox(height: 24);
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(Routes.newChat),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.summary, required this.myId});
  final ConversationSummary summary;
  final String? myId;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = summary;
    final unread = s.unreadCount > 0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: s.isGroup
          ? CircleAvatar(
              radius: 24,
              backgroundColor: t.colorScheme.surfaceContainerHighest,
              child: Icon(Icons.groups, color: t.colorScheme.primary),
            )
          : UserAvatar(url: s.otherAvatarUrl, radius: 24),
      title: Text(s.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
      subtitle: Text(s.preview(myId),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: unread ? t.colorScheme.onSurface : t.hintColor,
            fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
          )),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(timeAgo(s.lastMessageAt), style: TextStyle(color: t.hintColor, fontSize: 12)),
          const SizedBox(height: 4),
          if (unread)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: t.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(s.unreadCount > 99 ? '99+' : '${s.unreadCount}',
                  style: const TextStyle(
                      color: Colors.black, fontSize: 12, fontWeight: FontWeight.w800)),
            )
          else
            const SizedBox(height: 18),
        ],
      ),
      onTap: () => context.push(Routes.chat(s.id)),
    );
  }
}
