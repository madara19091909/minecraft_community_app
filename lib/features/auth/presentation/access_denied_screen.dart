import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/account_status.dart';
import 'auth_controller.dart';

/// Shown when the user is authenticated but not allowed in
/// (no profile, pending, suspended or banned) or when profile loading failed.
class AccessDeniedScreen extends ConsumerWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final (icon, title, body) = _content(auth);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 64, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(height: 16),
                Text(title,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(body, textAlign: TextAlign.center),
                const SizedBox(height: 28),
                if (auth.phase == AuthPhase.error)
                  FilledButton(onPressed: auth.refresh, child: const Text('Try again')),
                if (auth.phase == AuthPhase.ready && auth.profile?.status == AccountStatus.pending)
                  FilledButton(onPressed: auth.refresh, child: const Text('Check again')),
                const SizedBox(height: 10),
                OutlinedButton(onPressed: auth.signOut, child: const Text('Sign out')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (IconData, String, String) _content(AuthController auth) {
    if (auth.phase == AuthPhase.error) {
      return (Icons.wifi_off, 'Could not load your account', auth.errorMessage ?? '');
    }
    return switch (auth.profile?.status) {
      null => (Icons.person_off, 'No account found',
          'Your login is valid but you have not been added to the community yet. Contact an admin.'),
      AccountStatus.pending => (Icons.hourglass_top, 'Awaiting approval',
          'An admin needs to approve your account before you can enter.'),
      AccountStatus.suspended => (Icons.pause_circle, 'Account suspended',
          'Your account is temporarily suspended. Contact the moderation team.'),
      AccountStatus.banned => (Icons.block, 'Account banned',
          'Your account has been banned from this community.'),
      AccountStatus.active => (Icons.check_circle, 'Welcome', ''),
    };
  }
}
