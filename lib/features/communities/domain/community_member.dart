class CommunityMember {
  const CommunityMember({
    required this.communityId,
    required this.userId,
    required this.role,
    required this.status,
    required this.joinedAt,
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });

  final String communityId;
  final String userId;
  final String role;
  final String status;
  final DateTime joinedAt;
  final String username;
  final String displayName;
  final String? avatarUrl;

  factory CommunityMember.fromMap(Map<String, dynamic> m) {
    final name = (m['display_name'] as String?)?.trim();
    return CommunityMember(
      communityId: m['community_id'] as String,
      userId: m['user_id'] as String,
      role: m['role'] as String,
      status: m['status'] as String,
      joinedAt: DateTime.parse(m['joined_at'] as String),
      username: m['username'] as String,
      displayName: (name == null || name.isEmpty) ? m['username'] as String : name,
      avatarUrl: m['avatar_url'] as String?,
    );
  }
}
