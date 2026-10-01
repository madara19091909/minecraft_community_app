class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.isGroup,
    required this.lastMessageAt,
    required this.unreadCount,
    required this.memberCount,
    this.title,
    this.lastContent,
    this.lastSenderId,
    this.lastHasMedia = false,
    this.lastDeleted = false,
    this.otherUserId,
    this.otherUsername,
    this.otherDisplayName,
    this.otherAvatarUrl,
  });

  final String id;
  final bool isGroup;
  final String? title;
  final DateTime lastMessageAt;
  final int unreadCount;
  final int memberCount;
  final String? lastContent;
  final String? lastSenderId;
  final bool lastHasMedia;
  final bool lastDeleted;
  final String? otherUserId;
  final String? otherUsername;
  final String? otherDisplayName;
  final String? otherAvatarUrl;

  bool get hasMessages => lastSenderId != null;

  String get displayTitle {
    if (isGroup) return (title == null || title!.isEmpty) ? 'Group' : title!;
    final n = otherDisplayName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return otherUsername ?? 'Unknown user';
  }

  String preview(String? myId) {
    if (!hasMessages) return 'No messages yet';
    final prefix = lastSenderId == myId ? 'You: ' : '';
    if (lastDeleted) return '${prefix}Message deleted';
    final text = (lastContent ?? '').trim();
    if (text.isEmpty && lastHasMedia) return '${prefix}Photo';
    return '$prefix$text';
  }

  factory ConversationSummary.fromMap(Map<String, dynamic> m) => ConversationSummary(
        id: m['id'] as String,
        isGroup: m['is_group'] as bool,
        title: m['title'] as String?,
        lastMessageAt: DateTime.parse(m['last_message_at'] as String),
        unreadCount: (m['unread_count'] as num?)?.toInt() ?? 0,
        memberCount: (m['member_count'] as num?)?.toInt() ?? 0,
        lastContent: m['last_content'] as String?,
        lastSenderId: m['last_sender_id'] as String?,
        lastHasMedia: (m['last_has_media'] as bool?) ?? false,
        lastDeleted: (m['last_deleted'] as bool?) ?? false,
        otherUserId: m['other_user_id'] as String?,
        otherUsername: m['other_username'] as String?,
        otherDisplayName: m['other_display_name'] as String?,
        otherAvatarUrl: m['other_avatar_url'] as String?,
      );
}
