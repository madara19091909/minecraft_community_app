import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/notification_service.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/notification_repository.dart';

final notificationPushProvider = Provider<NotificationPushController>((ref) {
  final controller = NotificationPushController(
    ref.watch(notificationRepositoryProvider),
    ref.watch(authControllerProvider.select((a) => a.profile?.id)),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

/// Keeps the Android notification shade in sync with MC notifications while
/// the app is running. Background/terminated delivery is handled by the
/// optional FCM layer described in the push setup notes.
class NotificationPushController {
  NotificationPushController(this._repo, this._userId) {
    if (_userId == null) return;
    _start();
  }

  final NotificationRepository _repo;
  final String? _userId;
  RealtimeChannel? _channel;
  bool _disposed = false;

  Future<void> _start() async {
    await McNotificationService.instance.initialize();
    if (_disposed || _userId == null) return;

    _channel = _repo.subscribePush('system-notifications', _userId!, onInsert: _onInsert);
  }

  Future<void> _onInsert(String id) async {
    if (_disposed || _userId == null) return;
    try {
      final n = await _repo.fetchOne(id);
      if (n == null || n.isRead) return;
      final isMessage = n.type == 'message';
      final title = isMessage ? 'New message from ${n.actorName}' : 'MC';
      await McNotificationService.instance.show(
        id: n.id.hashCode,
        title: title,
        body: n.body,
        message: isMessage,
      );
    } catch (_) {
      // Notifications must never break the main app.
    }
  }

  void dispose() {
    _disposed = true;
    final channel = _channel;
    if (channel != null) _repo.removeChannel(channel);
  }
}
