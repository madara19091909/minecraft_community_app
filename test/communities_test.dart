import 'package:blockverse/features/communities/domain/community.dart';
import 'package:blockverse/features/communities/domain/community_member.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row({String privacy = 'public', String? role, String? status}) => {
      'id': 'c1', 'name': 'Redstone Lab', 'owner_id': 'u1', 'privacy': privacy,
      'member_count': 5, 'created_at': '2026-06-01T10:00:00Z',
      'my_role': role, 'my_status': status,
    };

void main() {
  test('public community is viewable by non-members', () {
    final c = Community.fromMap(_row());
    expect(c.canView, isTrue);
    expect(c.isMember, isFalse);
    expect(c.canModerate, isFalse);
  });

  test('private community hides content until membership is active', () {
    expect(Community.fromMap(_row(privacy: 'private')).canView, isFalse);
    final pending = Community.fromMap(_row(privacy: 'private', role: 'member', status: 'pending'));
    expect(pending.isPending, isTrue);
    expect(pending.canView, isFalse);
    final member = Community.fromMap(_row(privacy: 'private', role: 'member', status: 'active'));
    expect(member.canView, isTrue);
  });

  test('role capabilities', () {
    Community as(String role) => Community.fromMap(_row(role: role, status: 'active'));
    expect(as('moderator').canModerate, isTrue);
    expect(as('moderator').canManage, isFalse);
    expect(as('admin').canManage, isTrue);
    expect(as('admin').isOwner, isFalse);
    expect(as('owner').isOwner, isTrue);
    expect(as('member').canModerate, isFalse);
  });

  test('CommunityMember.fromMap falls back to username', () {
    final m = CommunityMember.fromMap({
      'community_id': 'c1', 'user_id': 'u2', 'role': 'member', 'status': 'active',
      'joined_at': '2026-06-02T10:00:00Z', 'username': 'alex', 'display_name': ' ',
    });
    expect(m.displayName, 'alex');
  });
}
