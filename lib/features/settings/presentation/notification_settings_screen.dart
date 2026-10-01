import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../domain/user_settings.dart';
import 'settings_providers.dart';
import 'settings_widgets.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> save(UserSettings Function(UserSettings) f) async {
      try {
        await ref.read(userSettingsProvider.notifier).update(f);
      } catch (e) {
        if (context.mounted) showErrorSnack(context, e);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ref.watch(userSettingsProvider).when(
            skipLoadingOnReload: true,
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(
              message: AppFailure.from(e).message,
              onRetry: ref.read(userSettingsProvider.notifier).load,
            ),
            data: (s) => ListView(children: [
              SettingsSection(title: 'Notify me about', children: [
                SwitchListTile(
                  title: const Text('Likes'),
                  value: s.notifyLikes,
                  onChanged: (v) => save((x) => x.copyWith(notifyLikes: v)),
                ),
                SwitchListTile(
                  title: const Text('Comments'),
                  value: s.notifyComments,
                  onChanged: (v) => save((x) => x.copyWith(notifyComments: v)),
                ),
                SwitchListTile(
                  title: const Text('New followers'),
                  value: s.notifyFollows,
                  onChanged: (v) => save((x) => x.copyWith(notifyFollows: v)),
                ),
                SwitchListTile(
                  title: const Text('Communities'),
                  subtitle: const Text('Requests, approvals and invitations'),
                  value: s.notifyCommunities,
                  onChanged: (v) => save((x) => x.copyWith(notifyCommunities: v)),
                ),
                SwitchListTile(
                  title: const Text('System'),
                  subtitle: const Text('Announcements and role changes'),
                  value: s.notifySystem,
                  onChanged: (v) => save((x) => x.copyWith(notifySystem: v)),
                ),
                SwitchListTile(
                  title: const Text('Messages'),
                  subtitle: const Text('Saved now; used when push notifications are added'),
                  value: s.notifyMessages,
                  onChanged: (v) => save((x) => x.copyWith(notifyMessages: v)),
                ),
              ]),
            ]),
          ),
    );
  }
}
