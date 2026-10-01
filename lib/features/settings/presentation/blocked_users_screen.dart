import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../home/presentation/post_providers.dart';
import 'settings_providers.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked users')),
      body: ref.watch(blockedUsersProvider).when(
            skipLoadingOnReload: true,
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(
              message: AppFailure.from(e).message,
              onRetry: () => ref.invalidate(blockedUsersProvider),
            ),
            data: (list) => list.isEmpty
                ? const EmptyView(
                    icon: Icons.block,
                    title: 'No blocked users',
                    subtitle: 'People you block will appear here.',
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final u = list[i];
                      return ListTile(
                        leading: UserAvatar(url: u.avatarUrl, radius: 22),
                        title: Text(u.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('@${u.username}'),
                        trailing: OutlinedButton(
                          onPressed: () async {
                            try {
                              await ref.read(settingsRepositoryProvider).unblock(u.userId);
                              ref.invalidate(blockedUsersProvider);
                              ref.read(feedProvider.notifier).refresh();
                            } catch (e) {
                              if (context.mounted) showErrorSnack(context, e);
                            }
                          },
                          child: const Text('Unblock'),
                        ),
                      );
                    },
                  ),
          ),
    );
  }
}
