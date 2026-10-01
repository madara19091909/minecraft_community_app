class Community {
  const Community({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.privacy,
    required this.memberCount,
    required this.createdAt,
    this.description,
    this.rules,
    this.iconUrl,
    this.bannerUrl,
    this.myRole,
    this.myStatus,
  });

  final String id;
  final String name;
  final String? description;
  final String? rules;
  final String? iconUrl;
  final String? bannerUrl;
  final String ownerId;
  final String privacy; // public | private
  final int memberCount;
  final DateTime createdAt;
  final String? myRole; // owner | admin | moderator | member
  final String? myStatus; // active | pending

  bool get isPrivate => privacy == 'private';
  bool get isMember => myStatus == 'active';
  bool get isPending => myStatus == 'pending';
  bool get isOwner => isMember && myRole == 'owner';
  bool get canView => !isPrivate || isMember;
  bool get canModerate => isMember && const {'owner', 'admin', 'moderator'}.contains(myRole);
  bool get canManage => isMember && const {'owner', 'admin'}.contains(myRole);

  factory Community.fromMap(Map<String, dynamic> m) => Community(
        id: m['id'] as String,
        name: m['name'] as String,
        description: m['description'] as String?,
        rules: m['rules'] as String?,
        iconUrl: m['icon_url'] as String?,
        bannerUrl: m['banner_url'] as String?,
        ownerId: m['owner_id'] as String,
        privacy: m['privacy'] as String,
        memberCount: (m['member_count'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(m['created_at'] as String),
        myRole: m['my_role'] as String?,
        myStatus: m['my_status'] as String?,
      );
}
