class PostMedia {
  const PostMedia({required this.url, required this.kind});
  final String url;
  final String kind; // image | video

  factory PostMedia.fromMap(Map<String, dynamic> m) =>
      PostMedia(url: m['url'] as String, kind: (m['kind'] as String?) ?? 'image');
}

class Post {
  const Post({
    required this.id,
    required this.authorId,
    required this.content,
    required this.createdAt,
    required this.username,
    required this.displayName,
    required this.authorRoleKey,
    required this.media,
    this.avatarUrl,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.likedByMe = false,
    this.communityId,
    this.communityName,
  });

  final String id;
  final String authorId;
  final String content;
  final DateTime createdAt;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String authorRoleKey;
  final List<PostMedia> media;
  final int likesCount;
  final int commentsCount;
  final bool likedByMe;
  final String? communityId;
  final String? communityName;

  Post copyWith({bool? likedByMe, int? likesCount, int? commentsCount}) => Post(
        id: id,
        authorId: authorId,
        content: content,
        createdAt: createdAt,
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
        authorRoleKey: authorRoleKey,
        media: media,
        communityId: communityId,
        communityName: communityName,
        likedByMe: likedByMe ?? this.likedByMe,
        likesCount: likesCount ?? this.likesCount,
        commentsCount: commentsCount ?? this.commentsCount,
      );

  factory Post.fromMap(Map<String, dynamic> m) {
    final name = (m['display_name'] as String?)?.trim();
    return Post(
      id: m['id'] as String,
      authorId: m['author_id'] as String,
      content: (m['content'] as String?) ?? '',
      createdAt: DateTime.parse(m['created_at'] as String),
      username: m['username'] as String,
      displayName: (name == null || name.isEmpty) ? m['username'] as String : name,
      avatarUrl: m['avatar_url'] as String?,
      authorRoleKey: (m['author_role_key'] as String?) ?? 'member',
      media: [
        for (final x in (m['media'] as List? ?? const []))
          PostMedia.fromMap(Map<String, dynamic>.from(x as Map)),
      ],
      likesCount: (m['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (m['comments_count'] as num?)?.toInt() ?? 0,
      likedByMe: (m['liked_by_me'] as bool?) ?? false,
      communityId: m['community_id'] as String?,
      communityName: m['community_name'] as String?,
    );
  }
}
