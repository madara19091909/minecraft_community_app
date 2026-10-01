import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/ui_helpers.dart';
import '../../auth/domain/account_status.dart';
import '../../auth/presentation/auth_controller.dart';
import 'settings_providers.dart';
import 'settings_widgets.dart';

class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref, SignOutScope scope) async {
    final everywhere = scope == SignOutScope.global;
    final ok = await confirmDialog(
      context,
      title: everywhere ? 'Sign out everywhere?' : 'Sign out other devices?',
      message: everywhere
          ? 'You will be signed out on this device and every other device.'
          : 'Your other devices will be signed out. This device stays signed in.',
      confirmLabel: 'Sign out',
    );
    if (!ok) return;
    try {
      await ref.read(settingsRepositoryProvider).signOut(scope);
      if (!everywhere && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Other devices were signed out.')));
      }
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authControllerProvider.select((a) => a.profile));
    final last = ref.watch(settingsRepositoryProvider).lastSignInAt;
    final t = Theme.of(context);
    final status = me?.status ?? AccountStatus.pending;

    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: ListView(children: [
        SettingsSection(title: 'Account status', children: [
          ListTile(
            leading: Icon(
              status == AccountStatus.active ? Icons.verified_user : Icons.warning_amber,
              color: status == AccountStatus.active ? t.colorScheme.primary : t.colorScheme.error,
            ),
            title: Text(status.name[0].toUpperCase() + status.name.substring(1)),
            subtitle: Text('Role: ${me?.roleKey ?? '—'}'),
          ),
        ]),
        SettingsSection(title: 'Sessions', children: [
          ListTile(
            leading: const Icon(Icons.phone_android),
            title: const Text('This device'),
            subtitle: Text(last == null ? 'Signed in' : 'Last sign-in: ${DateTime.tryParse(last)?.toLocal().toString().split('.').first ?? last}'),
          ),
          ListTile(
            leading: const Icon(Icons.devices_other),
            title: const Text('Sign out other devices'),
            onTap: () => _signOut(context, ref, SignOutScope.others),
          ),
          ListTile(
            leading: Icon(Icons.logout, color: t.colorScheme.error),
            title: Text('Sign out on all devices', style: TextStyle(color: t.colorScheme.error)),
            onTap: () => _signOut(context, ref, SignOutScope.global),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              'A per-device session list needs a server function and is not included yet.',
              style: TextStyle(color: t.hintColor, fontSize: 12.5),
            ),
          ),
        ]),
      ]),
    );
  }
}
