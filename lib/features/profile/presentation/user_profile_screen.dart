import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/ui_helpers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../home/presentation/post_providers.dart';
import '../../reports/presentation/report_sheet.dart';
import '../../settings/presentation/settings_providers.dart';
import 'profile_providers.dart';
import 'profile_view.dart';

class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key, required this.username});
  final String username;

  Future<void> _block(BuildContext context, WidgetRef ref, String userId, String name) async {
    final ok = await confirmDialog(
      context,
      title: 'Block $name?',
      message: "They won't be able to see your profile, follow you or message you, "
          "and you won't see their posts. You can unblock them in Settings → Privacy.",
      confirmLabel: 'Block',
    );
    if (!ok) return;
    try {
      await ref.read(settingsRepositoryProvider).block(userId);
      ref.read(feedProvider.notifier).refresh();
      ref.invalidate(profileByUsernameProvider);
      if (context.mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name blocked.')));
      }
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(authControllerProvider.select((a) => a.profile?.id));
    final p = ref.watch(profileByUsernameProvider(username)).valueOrNull;
    final canAct = p != null && p.id != myId;

    return Scaffold(
      appBar: AppBar(
        title: Text('@$username'),
        actions: [
          if (canAct)
            PopupMenuButton<String>(
              onSelected: (v) => v == 'report'
                  ? showReportSheet(context, targetType: 'user', targetId: p.id)
                  : _block(context, ref, p.id, p.displayName),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'report', child: Text('Report')),
                PopupMenuItem(value: 'block', child: Text('Block')),
              ],
            ),
        ],
      ),
      body: ProfileView(username: username),
    );
  }
}
