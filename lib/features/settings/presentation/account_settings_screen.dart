import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../auth/presentation/auth_controller.dart';
import 'settings_providers.dart';
import 'settings_widgets.dart';

class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  Future<void> _changeEmail(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change email'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'New email'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Send link')),
        ],
      ),
    );
    ctrl.dispose();
    if (value == null) return;
    if (!value.contains('@')) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid email.')));
      }
      return;
    }
    try {
      await ref.read(settingsRepositoryProvider).updateEmail(value);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Check your inbox to confirm the new address.')));
      }
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final a = TextEditingController();
    final b = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change password'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: a,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: b,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirm password'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Update')),
        ],
      ),
    );
    final p1 = a.text;
    final p2 = b.text;
    a.dispose();
    b.dispose();
    if (ok != true || !context.mounted) return;
    if (p1.length < 8) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Use at least 8 characters.')));
      return;
    }
    if (p1 != p2) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Passwords don't match.")));
      return;
    }
    try {
      await ref.read(settingsRepositoryProvider).updatePassword(p1);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated.')));
      }
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authControllerProvider.select((a) => a.profile));
    final email = ref.watch(settingsRepositoryProvider).email;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(children: [
        SettingsSection(title: 'Profile', children: [
          ListTile(
            leading: const Icon(Icons.alternate_email),
            title: const Text('Username'),
            subtitle: Text(me == null ? '' : '@${me.username}'),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit profile'),
            subtitle: const Text('Name, bio, avatar, banner, links'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.editProfile),
          ),
        ]),
        SettingsSection(title: 'Sign-in', children: [
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('Email'),
            subtitle: Text(email ?? '—'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _changeEmail(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: const Text('Password'),
            subtitle: const Text('Change your password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _changePassword(context, ref),
          ),
        ]),
      ]),
    );
  }
}
