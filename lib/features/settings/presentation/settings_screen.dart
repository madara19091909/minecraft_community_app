import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/permission_provider.dart';
import 'settings_widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Widget _tile(BuildContext context, IconData icon, String title, String route, {String? subtitle}) =>
      ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(route),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final canReview = ref.watch(permissionProvider('reports.review')).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SettingsSection(title: 'Account', children: [
            _tile(context, Icons.person_outline, 'Account', Routes.settingsAccount,
                subtitle: auth.profile == null ? null : '@${auth.profile!.username}'),
            _tile(context, Icons.lock_outline, 'Privacy', Routes.settingsPrivacy),
            _tile(context, Icons.notifications_none, 'Notifications', Routes.settingsNotifications),
          ]),
          SettingsSection(title: 'Preferences', children: [
            _tile(context, Icons.palette_outlined, 'Appearance', Routes.settingsAppearance),
          ]),
          SettingsSection(title: 'Security', children: [
            _tile(context, Icons.shield_outlined, 'Security', Routes.settingsSecurity),
          ]),
          if (canReview)
            SettingsSection(title: 'Moderation', children: [
              _tile(context, Icons.flag_outlined, 'Reports', Routes.reports,
                  subtitle: 'Review reported content'),
            ]),
          SettingsSection(title: 'About', children: [
            _tile(context, Icons.info_outline, 'About', Routes.settingsAbout),
          ]),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: auth.signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ),
        ],
      ),
    );
  }
}
