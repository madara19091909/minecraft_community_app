class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.mediaPath,
    this.replyTo,
    this.editedAt,
    this.deletedAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String? mediaPath;
  final String? replyTo;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
  bool get isEdited => editedAt != null;
  bool get hasMedia => mediaPath != null;

  factory Message.fromMap(Map<String, dynamic> m) => Message(
        id: m['id'] as String,
        conversationId: m['conversation_id'] as String,
        senderId: m['sender_id'] as String,
        content: (m['content'] as String?) ?? '',
        mediaPath: m['media_path'] as String?,
        replyTo: m['reply_to'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        editedAt: m['edited_at'] == null ? null : DateTime.parse(m['edited_at'] as String),
        deletedAt: m['deleted_at'] == null ? null : DateTime.parse(m['deleted_at'] as String),
      );
}

/// Keeps a newest-first list consistent when the same message arrives twice
/// (optimistic insert + realtime echo) or is updated (edit / delete).
List<Message> upsertMessage(List<Message> list, Message m) {
  final i = list.indexWhere((x) => x.id == m.id);
  if (i >= 0) {
    final copy = [...list];
    copy[i] = m;
    return copy;
  }
  return [m, ...list]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}
