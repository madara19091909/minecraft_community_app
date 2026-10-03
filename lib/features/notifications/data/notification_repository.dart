import 'dart:ui' show VoidCallback;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/app_notification.dart';

class NotificationRepository {
  NotificationRepository([SupabaseClient? client]) : _client = client ?? SupabaseService.client;
  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<List<AppNotification>> fetch({DateTime? before, int limit = 30}) async {
    try {
      var q = _client.from('notification_details').select();
      if (before != null) q = q.lt('created_at', before.toUtc().toIso8601String());
      final rows = await q.order('created_at', ascending: false).limit(limit);
      return [for (final r in rows) AppNotification.fromMap(r)];
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<AppNotification?> fetchOne(String id) async {
    try {
      final row = await _client
          .from('notification_details')
          .select()
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : AppNotification.fromMap(row);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<int> unreadCount() async {
    try {
      final r = await _client.rpc('unread_notification_count');
      return (r as num).toInt();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _client
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id)
          .isFilter('read_at', null);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> markAllRead() async {
    try {
      await _client
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .isFilter('read_at', null);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  RealtimeChannel subscribePush(String name, String userId, {required Future<void> Function(String id) onInsert}) {
    final channel = _client.channel('$name:$userId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'recipient_id',
        value: userId,
      ),
      callback: (payload) {
        final id = payload.newRecord['id']?.toString();
        if (id != null && id.isNotEmpty) onInsert(id);
      },
    );
    channel.subscribe();
    return channel;
  }

  Future<void> removeChannel(RealtimeChannel c) async {
    try {
      await _client.removeChannel(c);
    } catch (_) {}
  }

  /// Fires [onChange] for new/changed notifications of [userId]
  /// (and once more after a reconnect so nothing is missed offline).
  RealtimeChannel subscribe(String name, String userId, {required VoidCallback onChange}) {
    var subscribedBefore = false;
    final channel = _client.channel('$name:$userId');
    for (final event in [PostgresChangeEvent.insert, PostgresChangeEvent.update]) {
      channel.onPostgresChanges(
        event: event,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'recipient_id',
          value: userId,
        ),
        callback: (_) => onChange(),
      );
    }
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        if (subscribedBefore) onChange();
        subscribedBefore = true;
      }
    });
    return channel;
  }
}
