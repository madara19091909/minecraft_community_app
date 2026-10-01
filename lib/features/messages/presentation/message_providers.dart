import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/utils/paged.dart';
import '../../../core/utils/picked_image.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/message_repository.dart';
import '../domain/chat_info.dart';
import '../domain/conversation_summary.dart';
import '../domain/message.dart';

final messageRepositoryProvider = Provider<MessageRepository>((_) => MessageRepository());

// ---------------- Inbox ----------------
class InboxController extends PagedNotifier<ConversationSummary> {
  InboxController(this._repo) {
    final uid = _repo.currentUserId;
    if (uid != null) {
      _channel = _repo.subscribeInbox(userId: uid, onChange: _scheduleRefresh);
    }
  }

  final MessageRepository _repo;
  RealtimeChannel? _channel;
  Timer? _debounce;

  @override
  int get pageSize => 30;

  @override
  Future<List<ConversationSummary>> fetchPage(ConversationSummary? last) =>
      _repo.fetchInbox(before: last?.lastMessageAt, limit: pageSize);

  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), refresh);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    final c = _channel;
    if (c != null) _repo.removeChannel(c);
    super.dispose();
  }
}

/// Rebuilt when the signed-in user changes. Kept alive by the main shell (unread badge).
final inboxProvider = StateNotifierProvider<InboxController, PagedState<ConversationSummary>>((ref) {
  ref.watch(authControllerProvider.select((a) => a.profile?.id));
  return InboxController(ref.watch(messageRepositoryProvider));
});

final unreadMessagesProvider = Provider<int>(
  (ref) => ref.watch(inboxProvider).items.fold<int>(0, (sum, c) => sum + c.unreadCount),
);

// ---------------- Chat messages ----------------
class ChatController extends PagedNotifier<Message> {
  ChatController(this._repo, this.conversationId, this._myId) {
    _channel = _repo.subscribeToMessages(
      conversationId,
      onChange: _onRemote,
      onReconnect: refresh,
    );
    _scheduleRead();
  }

  final MessageRepository _repo;
  final String conversationId;
  final String? _myId;
  late final RealtimeChannel _channel;
  Timer? _readTimer;

  @override
  int get pageSize => 40;

  @override
  Future<List<Message>> fetchPage(Message? last) =>
      _repo.fetchMessages(conversationId, before: last?.createdAt, limit: pageSize);

  void _onRemote(Message m) {
    if (!mounted) return;
    mutate((l) => upsertMessage(l, m));
    if (m.senderId != _myId) _scheduleRead();
  }

  void _scheduleRead() {
    _readTimer?.cancel();
    _readTimer = Timer(const Duration(milliseconds: 600), () => _repo.markRead(conversationId));
  }

  Future<void> send({String content = '', PickedImage? image, String? replyTo}) async {
    final m = await _repo.sendMessage(
      conversationId: conversationId,
      content: content,
      image: image,
      replyTo: replyTo,
    );
    mutate((l) => upsertMessage(l, m));
  }

  Future<void> edit(Message m, String content) async {
    final updated = await _repo.editMessage(m.id, content);
    mutate((l) => upsertMessage(l, updated));
  }

  Future<void> delete(Message m) async {
    final updated = await _repo.deleteMessage(m);
    mutate((l) => upsertMessage(l, updated));
  }

  @override
  void dispose() {
    _readTimer?.cancel();
    _repo.markRead(conversationId);
    _repo.removeChannel(_channel);
    super.dispose();
  }
}

final chatControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatController, PagedState<Message>, String>((ref, conversationId) {
  final myId = ref.watch(authControllerProvider.select((a) => a.profile?.id));
  return ChatController(ref.watch(messageRepositoryProvider), conversationId, myId);
});

// ---------------- Chat info (members + read receipts) ----------------
class ChatInfoController extends StateNotifier<AsyncValue<ChatInfo>> {
  ChatInfoController(this._repo, this._conversationId) : super(const AsyncValue.loading()) {
    _load();
    _channel = _repo.subscribeToReads(
      _conversationId,
      onRead: (userId, t) {
        final info = state.valueOrNull;
        if (mounted && info != null) state = AsyncValue.data(info.withMemberRead(userId, t));
      },
      onReconnect: _load,
    );
  }

  final MessageRepository _repo;
  final String _conversationId;
  late final RealtimeChannel _channel;

  Future<void> _load() async {
    try {
      final info = await _repo.fetchChatInfo(_conversationId);
      if (mounted) state = AsyncValue.data(info);
    } catch (e, st) {
      if (mounted && state.valueOrNull == null) {
        state = AsyncValue.error(AppFailure.from(e), st);
      }
    }
  }

  @override
  void dispose() {
    _repo.removeChannel(_channel);
    super.dispose();
  }
}

final chatInfoProvider = StateNotifierProvider.autoDispose
    .family<ChatInfoController, AsyncValue<ChatInfo>, String>(
  (ref, id) => ChatInfoController(ref.watch(messageRepositoryProvider), id),
);

// ---------------- Misc ----------------
/// Signed URLs are valid for 6h and cached for the session (images are also
/// disk-cached by path, so a new URL never re-downloads the file).
final chatImageUrlProvider = FutureProvider.family<String, String>(
  (ref, path) => ref.watch(messageRepositoryProvider).signedUrl(path),
);

final userSearchProvider = FutureProvider.autoDispose.family<List<UserSummary>, String>(
  (ref, query) => ref.watch(messageRepositoryProvider).searchUsers(query),
);
