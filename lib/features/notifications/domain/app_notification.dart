class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.createdAt,
    this.actorId,
    this.actorUsername,
    this.actorDisplayName,
    this.actorAvatarUrl,
    this.postId,
    this.postSnippet,
    this.communityId,
    this.communityName,
    this.message,
    this.readAt,
  });

  final String id;
  final String type;
  final DateTime createdAt;
  final String? actorId;
  final String? actorUsername;
  final String? actorDisplayName;
  final String? actorAvatarUrl;
  final String? postId;
  final String? postSnippet;
  final String? communityId;
  final String? communityName;
  final String? message;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  String get actorName {
    final n = actorDisplayName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return actorUsername ?? 'Someone';
  }

  /// Text after the (bold) actor name; for actor-less types this is the full sentence.
  String get body {
    final c = communityName ?? 'a community';
    return switch (type) {
      'like' => 'liked your post',
      'comment' => 'commented on your post',
      'follow' => 'started following you',
      'community_request' => 'wants to join $c',
      'community_added' => 'added you to $c',
      'community_approved' => 'Your request to join $c was approved',
      'role_change' => 'Your role was changed',
      'message' => message ?? 'sent you a message',
      _ => message ?? 'Announcement',
    };
  }

  /// Whether the sentence starts with the actor's name.
  bool get startsWithActor =>
      actorId != null && const {'like', 'comment', 'follow', 'community_request', 'community_added', 'message'}.contains(type);

  AppNotification copyWith({DateTime? readAt}) => AppNotification(
        id: id,
        type: type,
        createdAt: createdAt,
        actorId: actorId,
        actorUsername: actorUsername,
        actorDisplayName: actorDisplayName,
        actorAvatarUrl: actorAvatarUrl,
        postId: postId,
        postSnippet: postSnippet,
        communityId: communityId,
        communityName: communityName,
        message: message,
        readAt: readAt ?? this.readAt,
      );

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
        id: m['id'] as String,
        type: m['type'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
        actorId: m['actor_id'] as String?,
        actorUsername: m['actor_username'] as String?,
        actorDisplayName: m['actor_display_name'] as String?,
        actorAvatarUrl: m['actor_avatar_url'] as String?,
        postId: m['post_id'] as String?,
        postSnippet: m['post_snippet'] as String?,
        communityId: m['community_id'] as String?,
        communityName: m['community_name'] as String?,
        message: m['message'] as String?,
        readAt: m['read_at'] == null ? null : DateTime.parse(m['read_at'] as String),
      );
}
