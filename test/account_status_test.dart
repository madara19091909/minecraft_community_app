import 'package:blockverse/features/auth/domain/account_status.dart';
import 'package:blockverse/features/auth/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AccountStatus.parse maps known values and defaults to pending', () {
    expect(AccountStatus.parse('active'), AccountStatus.active);
    expect(AccountStatus.parse('banned'), AccountStatus.banned);
    expect(AccountStatus.parse('weird'), AccountStatus.pending);
    expect(AccountStatus.parse(null), AccountStatus.pending);
  });

  test('Profile.fromMap reads role and status', () {
    final p = Profile.fromMap({
      'id': 'u1',
      'username': 'steve',
      'display_name': null,
      'avatar_url': null,
      'status': 'suspended',
      'roles': {'key': 'creator'},
    });
    expect(p.displayName, 'steve');
    expect(p.roleKey, 'creator');
    expect(p.isActive, isFalse);
  });
}
