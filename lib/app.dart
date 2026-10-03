import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/presentation/settings_providers.dart';
import 'features/notifications/presentation/notification_push_controller.dart';

class BlockverseApp extends ConsumerWidget {
  const BlockverseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notificationPushProvider);
    final look = ref.watch(appearanceProvider);
    return MaterialApp.router(
      title: 'mcc',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(look.accent),
      darkTheme: AppTheme.dark(look.accent),
      themeMode: look.mode,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
