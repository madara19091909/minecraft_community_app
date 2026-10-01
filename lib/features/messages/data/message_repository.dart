import 'dart:ui' show VoidCallback;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/picked_image.dart';
import '../domain/chat_info.dart';
import '../domain/conversation_summary.dart';
import '../domain/message.dart';

class UserSummary {
  const UserSummary({required this.id, required this.username, required this.displayName, this.avatarUrl});
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;

  factory UserSummary.fromMap(Map<String, dynamic> m) {
    final n = (m['display_name'] as String?)?.trim();
    return UserSummary(
      id: m['id'] as String,
      username: m['username'] as String,
      displayName: (n == null || n.isEmpty) ? m['username'] as String : n,
      avatarUrl: m['avatar_url'] as String?,
    );
  }
}

class MessageRepository {
  MessageRepository([SupabaseClient? client]) : _client = client ?? SupabaseService.client;
  final SupabaseClient _client;
  static const _bucket = 'chat-media';

  String? get currentUserId => _client.auth.currentUser?.id;
  String get _uid => _client.auth.currentUser!.id;

  // ---------- Inbox ----------
  Future<List<ConversationSummary>> fetchInbox({DateTime? before, int limit = 30}) async {
    try {
      var q = _client.from('conversation_summaries').select();
      if (before != null) q = q.lt('last_message_at', before.toUtc().toIso8601String());
      final rows = await q.order('last_message_at', ascending: false).limit(limit);
      return [for (final r in rows) ConversationSummary.fromMap(r)];
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<String> startDirect(String otherUserId) async {
    try {
      final id = await _client.rpc('start_direct_conversation', params: {'p_other': otherUserId});
      return id as String;
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<String> createGroup(String title, List<String> memberIds) async {
    try {
      final id = await _client.rpc('create_group_conversation',
          params: {'p_title': title.trim(), 'p_members': memberIds});
      return id as String;
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> leaveGroup(String conversationId) async {
    try {
      await _client
          .from('conversation_members')
          .delete()
          .eq('conversation_id', conversationId)
          .eq('user_id', _uid);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<List<UserSummary>> searchUsers(String query) async {
    final q = query.replaceAll(RegExp(r'[,()%_\\]'), ' ').trim();
    if (q.length < 2) return const [];
    try {
      final rows = await _client
          .from('user_directory')
          .select('id, username, display_name, avatar_url')
          .neq('id', _uid)
          .or('username.ilike.%$q%,display_name.ilike.%$q%')
          .limit(20);
      return [for (final r in rows) UserSummary.fromMap(r)];
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  // ---------- Chat ----------
  Future<ChatInfo> fetchChatInfo(String conversationId) async {
    try {
      final conv = await _client
          .from('conversations')
          .select('id, is_group, title')
          .eq('id', conversationId)
          .single();
      final rows = await _client
          .from('conversation_member_details')
          .select()
          .eq('conversation_id', conversationId);
      final members = <String, ChatMember>{
        for (final r in rows) r['user_id'] as String: ChatMember.fromMap(r),
      };
      return ChatInfo(
        conversationId: conversationId,
        isGroup: conv['is_group'] as bool,
        title: conv['title'] as String?,
        members: members,
      );
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<List<Message>> fetchMessages(String conversationId, {DateTime? before, int limit = 40}) async {
    try {
      var q = _client.from('messages').select().eq('conversation_id', conversationId);
      if (before != null) q = q.lt('created_at', before.toUtc().toIso8601String());
      final rows = await q.order('created_at', ascending: false).limit(limit);
      return [for (final r in rows) Message.fromMap(r)];
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<Message> sendMessage({
    required String conversationId,
    String content = '',
    PickedImage? image,
    String? replyTo,
  }) async {
    String? path;
    try {
      if (image != null) {
        path = '$conversationId/$_uid/${DateTime.now().microsecondsSinceEpoch}.${image.extension}';
        await _client.storage.from(_bucket).uploadBinary(path, image.bytes,
            fileOptions: FileOptions(contentType: image.contentType));
      }
      final row = await _client
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': _uid,
            'content': content.trim(),
            if (path != null) 'media_path': path,
            if (replyTo != null) 'reply_to': replyTo,
          })
          .select()
          .single();
      return Message.fromMap(row);
    } catch (e) {
      if (path != null) {
        try {
          await _client.storage.from(_bucket).remove([path]);
        } catch (_) {}
      }
      throw AppFailure.from(e);
    }
  }

  Future<Message> editMessage(String id, String content) async {
    try {
      final row = await _client
          .from('messages')
          .update({'content': content.trim()})
          .eq('id', id)
          .select()
          .single();
      return Message.fromMap(row);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<Message> deleteMessage(Message m) async {
    try {
      final row = await _client
          .from('messages')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', m.id)
          .select()
          .single();
      if (m.mediaPath != null) {
        try {
          await _client.storage.from(_bucket).remove([m.mediaPath!]);
        } catch (_) {}
      }
      return Message.fromMap(row);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> markRead(String conversationId) async {
    try {
      await _client.rpc('mark_conversation_read', params: {'p_conversation': conversationId});
    } catch (_) {
      // Non-critical; it will be retried on the next message / open.
    }
  }

  Future<String> signedUrl(String path) async {
    try {
      return await _client.storage.from(_bucket).createSignedUrl(path, 6 * 3600);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  // ---------- Realtime ----------
  Future<void> removeChannel(RealtimeChannel c) async {
    try {
      await _client.removeChannel(c);
    } catch (_) {}
  }

  /// Inserts/updates of messages in one conversation. [onReconnect] fires when the
  /// socket re-subscribes so callers can re-fetch anything missed while offline.
  RealtimeChannel subscribeToMessages(
    String conversationId, {
    required void Function(Message) onChange,
    required VoidCallback onReconnect,
  }) {
    var subscribedBefore = false;
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'conversation_id',
      value: conversationId,
    );
    final channel = _client.channel('chat-messages:$conversationId');
    for (final event in [PostgresChangeEvent.insert, PostgresChangeEvent.update]) {
      channel.onPostgresChanges(
        event: event,
        schema: 'public',
        table: 'messages',
        filter: filter,
        callback: (payload) {
          try {
            onChange(Message.fromMap(payload.newRecord));
          } catch (_) {}
        },
      );
    }
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        if (subscribedBefore) onReconnect();
        subscribedBefore = true;
      }
    });
    return channel;
  }

  /// Other members' read receipts for one conversation.
  RealtimeChannel subscribeToReads(
    String conversationId, {
    required void Function(String userId, DateTime readAt) onRead,
    required VoidCallback onReconnect,
  }) {
    var subscribedBefore = false;
    final channel = _client.channel('chat-reads:$conversationId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'conversation_members',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'conversation_id',
        value: conversationId,
      ),
      callback: (payload) {
        try {
          final r = payload.newRecord;
          onRead(r['user_id'] as String, DateTime.parse(r['last_read_at'] as String));
        } catch (_) {}
      },
    );
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        if (subscribedBefore) onReconnect();
        subscribedBefore = true;
      }
    });
    return channel;
  }

  /// Any new/changed message in my conversations or my own read marker.
  RealtimeChannel subscribeInbox({required String userId, required VoidCallback onChange}) {
    var subscribedBefore = false;
    final channel = _client.channel('inbox:$userId');
    for (final event in [PostgresChangeEvent.insert, PostgresChangeEvent.update]) {
      channel.onPostgresChanges(
        event: event,
        schema: 'public',
        table: 'messages',
        callback: (_) => onChange(),
      );
    }
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'conversation_members',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (_) => onChange(),
    );
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        if (subscribedBefore) onChange();
        subscribedBefore = true;
      }
    });
    return channel;
  }
}
