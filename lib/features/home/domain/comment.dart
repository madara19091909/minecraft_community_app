class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.content,
    required this.createdAt,
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String postId;
  final String authorId;
  final String content;
  final DateTime createdAt;
  final String username;
  final String displayName;
  final String? avatarUrl;

  factory Comment.fromMap(Map<String, dynamic> m) {
    final name = (m['display_name'] as String?)?.trim();
    return Comment(
      id: m['id'] as String,
      postId: m['post_id'] as String,
      authorId: m['author_id'] as String,
      content: m['content'] as String,
      createdAt: DateTime.parse(m['created_at'] as String),
      username: m['username'] as String,
      displayName: (name == null || name.isEmpty) ? m['username'] as String : name,
      avatarUrl: m['avatar_url'] as String?,
    );
  }
}
