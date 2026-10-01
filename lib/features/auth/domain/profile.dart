import 'account_status.dart';

class Profile {
  const Profile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.status,
    required this.roleKey,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String displayName;
  final AccountStatus status;
  final String roleKey;
  final String? avatarUrl;

  bool get isActive => status == AccountStatus.active;

  factory Profile.fromMap(Map<String, dynamic> map) {
    final role = map['roles'] as Map<String, dynamic>?;
    return Profile(
      id: map['id'] as String,
      username: map['username'] as String,
      displayName: (map['display_name'] as String?) ?? map['username'] as String,
      avatarUrl: map['avatar_url'] as String?,
      status: AccountStatus.parse(map['status'] as String?),
      roleKey: (role?['key'] as String?) ?? 'member',
    );
  }
}
