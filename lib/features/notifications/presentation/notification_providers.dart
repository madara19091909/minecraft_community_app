import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/paged.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/notification_repository.dart';
import '../domain/app_notification.dart';

final notificationRepositoryProvider =
    Provider<NotificationRepository>((_) => NotificationRepository());

/// Unread counter shown on the bell. Lives for the whole session (realtime).
class NotificationBadgeController extends StateNotifier<int> {
  NotificationBadgeController(this._repo) : super(0) {
    refresh();
    final uid = _repo.currentUserId;
    if (uid != null) {
      _channel = _repo.subscribe('notif-badge', uid, onChange: refresh);
    }
  }

  final NotificationRepository _repo;
  RealtimeChannel? _channel;

  Future<void> refresh() async {
    try {
      final n = await _repo.unreadCount();
      if (mounted) state = n;
    } catch (_) {
      // Keep the last known count.
    }
  }

  @override
  void dispose() {
    final c = _channel;
    if (c != null) _repo.removeChannel(c);
    super.dispose();
  }
}

final notificationBadgeProvider =
    StateNotifierProvider<NotificationBadgeController, int>((ref) {
  ref.watch(authControllerProvider.select((a) => a.profile?.id));
  return NotificationBadgeController(ref.watch(notificationRepositoryProvider));
});

/// The list; only alive while the notifications screen is open.
class NotificationsController extends PagedNotifier<AppNotification> {
  NotificationsController(this._repo) {
    final uid = _repo.currentUserId;
    if (uid != null) {
      _channel = _repo.subscribe('notif-list', uid, onChange: _schedule);
    }
  }

  final NotificationRepository _repo;
  RealtimeChannel? _channel;
  Timer? _debounce;

  @override
  int get pageSize => 30;

  @override
  Future<List<AppNotification>> fetchPage(AppNotification? last) =>
      _repo.fetch(before: last?.createdAt, limit: pageSize);

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), refresh);
  }

  Future<void> markRead(AppNotification n) async {
    if (n.isRead) return;
    await _repo.markRead(n.id);
    mutate((l) => [for (final x in l) x.id == n.id ? x.copyWith(readAt: DateTime.now()) : x]);
  }

  Future<void> markAllRead() async {
    await _repo.markAllRead();
    final now = DateTime.now();
    mutate((l) => [for (final x in l) x.isRead ? x : x.copyWith(readAt: now)]);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    final c = _channel;
    if (c != null) _repo.removeChannel(c);
    super.dispose();
  }
}

final notificationsProvider = StateNotifierProvider.autoDispose<NotificationsController,
    PagedState<AppNotification>>(
  (ref) => NotificationsController(ref.watch(notificationRepositoryProvider)),
);
