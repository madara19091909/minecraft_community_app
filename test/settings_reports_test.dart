import 'package:blockverse/features/reports/domain/report.dart';
import 'package:blockverse/features/settings/domain/user_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UserSettings defaults are permissive and round-trip through the DB map', () {
    const d = UserSettings();
    expect(d.whoCanMessage, 'everyone');
    expect(d.profileVisibility, 'everyone');
    expect(d.notifyLikes && d.notifyComments && d.notifySystem, isTrue);

    final changed = d.copyWith(whoCanMessage: 'nobody', notifyLikes: false);
    final map = changed.toMap('u1');
    expect(map['user_id'], 'u1');
    expect(map['who_can_message'], 'nobody');
    final back = UserSettings.fromMap(map);
    expect(back.whoCanMessage, 'nobody');
    expect(back.notifyLikes, isFalse);
    expect(back.notifyComments, isTrue);
  });

  test('UserSettings.fromMap tolerates missing columns', () {
    final s = UserSettings.fromMap({});
    expect(s.profileVisibility, 'everyone');
    expect(s.notifyMessages, isTrue);
  });

  test('Report parsing and labels', () {
    final r = Report.fromMap({
      'id': 'r1', 'reporter_id': 'u1', 'reporter_username': 'alex',
      'target_type': 'post', 'target_id': 'p1', 'target_owner_id': 'u2',
      'owner_username': 'sam', 'target_snapshot': 'spammy text',
      'reason': 'spam', 'status': 'pending', 'created_at': '2026-09-01T10:00:00Z',
    });
    expect(r.reasonLabel, 'Spam');
    expect(r.typeLabel, 'Post');
    expect(r.isOpen, isTrue);
    final done = Report.fromMap({
      'id': 'r2', 'reporter_id': 'u1', 'target_type': 'user', 'target_id': 'u3',
      'reason': 'other', 'status': 'resolved', 'created_at': '2026-09-01T10:00:00Z',
      'reviewed_at': '2026-09-01T12:00:00Z',
    });
    expect(done.isOpen, isFalse);
    expect(done.reviewedAt, isNotNull);
  });

  test('every report reason has a label', () {
    expect(reportReasons.keys, containsAll(['spam', 'harassment', 'hate', 'sexual', 'violence', 'impersonation', 'other']));
    expect(reportStatuses, ['pending', 'reviewing', 'resolved', 'rejected']);
  });
}
