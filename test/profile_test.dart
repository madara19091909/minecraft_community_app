import 'package:blockverse/core/utils/validators.dart';
import 'package:blockverse/features/profile/domain/profile_details.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('username validator', () {
    expect(Validators.username('steve_01'), isNull);
    expect(Validators.username('Steve'), isNotNull);
    expect(Validators.username('ab'), isNotNull);
  });

  test('optional url validator accepts bare domains and rejects junk', () {
    expect(Validators.optionalUrl(''), isNull);
    expect(Validators.optionalUrl('youtube.com/@steve'), isNull);
    expect(Validators.optionalUrl('not a link'), isNotNull);
  });

  test('ProfileDetails.fromMap', () {
    final p = ProfileDetails.fromMap({
      'id': 'u1', 'username': 'alex', 'display_name': '',
      'links': {'youtube': 'youtube.com/x', 'tiktok': ''},
      'role_key': 'creator', 'role_name': 'Creator',
      'created_at': '2026-03-01T10:00:00Z',
      'followers_count': 12, 'following_count': 3, 'is_following': true,
      'minecraft_edition': 'bedrock',
    });
    expect(p.displayName, 'alex');
    expect(p.links.keys, ['youtube']);
    expect(p.followersCount, 12);
    expect(p.editionLabel, 'Bedrock Edition');
  });
}
