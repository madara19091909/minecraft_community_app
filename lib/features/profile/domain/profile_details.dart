class ProfileDetails {
  const ProfileDetails({
    required this.id,
    required this.username,
    required this.displayName,
    required this.roleKey,
    required this.roleName,
    required this.createdAt,
    required this.links,
    this.avatarUrl,
    this.bannerUrl,
    this.bio,
    this.minecraftUsername,
    this.minecraftEdition,
    this.followersCount = 0,
    this.followingCount = 0,
    this.isFollowing = false,
    this.isRestricted = false,
  });

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bannerUrl;
  final String? bio;
  final String? minecraftUsername;
  final String? minecraftEdition; // 'java' | 'bedrock'
  final Map<String, String> links; // youtube, tiktok, discord, website
  final String roleKey;
  final String roleName;
  final DateTime createdAt;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;
  final bool isRestricted; // owner limits the full profile to followers

  String get editionLabel => switch (minecraftEdition) {
        'java' => 'Java Edition',
        'bedrock' => 'Bedrock Edition',
        _ => '',
      };

  factory ProfileDetails.fromMap(Map<String, dynamic> m) {
    final rawLinks = (m['links'] as Map?) ?? const {};
    return ProfileDetails(
      id: m['id'] as String,
      username: m['username'] as String,
      displayName: (m['display_name'] as String?)?.trim().isNotEmpty == true
          ? m['display_name'] as String
          : m['username'] as String,
      avatarUrl: m['avatar_url'] as String?,
      bannerUrl: m['banner_url'] as String?,
      bio: m['bio'] as String?,
      minecraftUsername: m['minecraft_username'] as String?,
      minecraftEdition: m['minecraft_edition'] as String?,
      links: {
        for (final e in rawLinks.entries)
          if (e.value is String && (e.value as String).isNotEmpty)
            e.key.toString(): e.value as String,
      },
      roleKey: m['role_key'] as String,
      roleName: m['role_name'] as String,
      createdAt: DateTime.parse(m['created_at'] as String),
      followersCount: (m['followers_count'] as num?)?.toInt() ?? 0,
      followingCount: (m['following_count'] as num?)?.toInt() ?? 0,
      isFollowing: (m['is_following'] as bool?) ?? false,
      isRestricted: (m['is_restricted'] as bool?) ?? false,
    );
  }
}
