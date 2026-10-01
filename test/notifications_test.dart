import 'package:blockverse/features/notifications/domain/app_notification.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row(String type, {String? actor = 'u2', String? read}) => {
      'id': 'n1', 'type': type, 'created_at': '2026-08-01T10:00:00Z',
      'actor_id': actor, 'actor_username': 'alex', 'actor_display_name': ' ',
      'community_name': 'Redstone Lab', 'message': 'Maintenance at 22:00',
      'read_at': read,
    };

void main() {
  test('actor-based sentences', () {
    final like = AppNotification.fromMap(_row('like'));
    expect(like.startsWithActor, isTrue);
    expect(like.actorName, 'alex');
    expect(like.body, 'liked your post');
    expect(AppNotification.fromMap(_row('community_request')).body, 'wants to join Redstone Lab');
  });

  test('actor-less sentences are complete', () {
    final approved = AppNotification.fromMap(_row('community_approved'));
    expect(approved.startsWithActor, isFalse);
    expect(approved.body, 'Your request to join Redstone Lab was approved');
    final sys = AppNotification.fromMap(_row('system', actor: null));
    expect(sys.body, 'Maintenance at 22:00');
    expect(sys.startsWithActor, isFalse);
  });

  test('read state and copyWith', () {
    final n = AppNotification.fromMap(_row('follow'));
    expect(n.isRead, isFalse);
    final r = n.copyWith(readAt: DateTime.utc(2026, 8, 1, 11));
    expect(r.isRead, isTrue);
    expect(r.id, n.id);
    expect(AppNotification.fromMap(_row('follow', read: '2026-08-01T10:30:00Z')).isRead, isTrue);
  });
}
