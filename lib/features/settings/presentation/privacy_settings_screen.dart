import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../domain/user_settings.dart';
import 'settings_providers.dart';
import 'settings_widgets.dart';

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  static const _who = {
    'everyone': 'Everyone',
    'following': 'People I follow',
    'nobody': 'No one',
  };

  Future<void> _save(BuildContext context, WidgetRef ref, UserSettings Function(UserSettings) f) async {
    try {
      await ref.read(userSettingsProvider.notifier).update(f);
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: async.when(
        skipLoadingOnReload: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: AppFailure.from(e).message,
          onRetry: ref.read(userSettingsProvider.notifier).load,
        ),
        data: (s) => ListView(children: [
          SettingsSection(title: 'Who can…', children: [
            ChoiceTile<String>(
              title: 'Message me',
              value: s.whoCanMessage,
              options: _who,
              onChanged: (v) => _save(context, ref, (x) => x.copyWith(whoCanMessage: v)),
            ),
            ChoiceTile<String>(
              title: 'See my full profile',
              value: s.profileVisibility,
              options: const {'everyone': 'Everyone', 'followers': 'My followers only'},
              subtitle: 'Others still see your name and avatar',
              onChanged: (v) => _save(context, ref, (x) => x.copyWith(profileVisibility: v)),
            ),
            ChoiceTile<String>(
              title: 'Mention me',
              value: s.whoCanMention,
              options: _who,
              subtitle: 'Applies once mentions launch',
              onChanged: (v) => _save(context, ref, (x) => x.copyWith(whoCanMention: v)),
            ),
          ]),
          SettingsSection(title: 'Safety', children: [
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Blocked users'),
              subtitle: const Text('They cannot see you, follow you or message you'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.settingsBlocked),
            ),
          ]),
        ]),
      ),
    );
  }
}
