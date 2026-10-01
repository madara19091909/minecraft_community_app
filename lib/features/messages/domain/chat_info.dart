class ChatMember {
  const ChatMember({
    required this.userId,
    required this.role,
    required this.username,
    required this.displayName,
    required this.lastReadAt,
    this.avatarUrl,
  });

  final String userId;
  final String role;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final DateTime lastReadAt;

  ChatMember withRead(DateTime t) => ChatMember(
        userId: userId,
        role: role,
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
        lastReadAt: t,
      );

  factory ChatMember.fromMap(Map<String, dynamic> m) {
    final name = (m['display_name'] as String?)?.trim();
    return ChatMember(
      userId: m['user_id'] as String,
      role: m['role'] as String,
      username: m['username'] as String,
      displayName: (name == null || name.isEmpty) ? m['username'] as String : name,
      avatarUrl: m['avatar_url'] as String?,
      lastReadAt: DateTime.parse(m['last_read_at'] as String),
    );
  }
}

class ChatInfo {
  const ChatInfo({
    required this.conversationId,
    required this.isGroup,
    required this.members,
    this.title,
  });

  final String conversationId;
  final bool isGroup;
  final String? title;
  final Map<String, ChatMember> members;

  ChatMember? other(String? myId) {
    for (final m in members.values) {
      if (m.userId != myId) return m;
    }
    return null;
  }

  String titleFor(String? myId) {
    if (isGroup) return (title == null || title!.isEmpty) ? 'Group' : title!;
    return other(myId)?.displayName ?? 'Chat';
  }

  /// How many other members have read up to (and including) [messageTime].
  int readersOf(DateTime messageTime, String? myId) => members.values
      .where((m) => m.userId != myId && !m.lastReadAt.isBefore(messageTime))
      .length;

  ChatInfo withMemberRead(String userId, DateTime t) {
    final m = members[userId];
    if (m == null) return this;
    return ChatInfo(
      conversationId: conversationId,
      isGroup: isGroup,
      title: title,
      members: {...members, userId: m.withRead(t)},
    );
  }
}
