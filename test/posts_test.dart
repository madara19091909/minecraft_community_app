import 'package:blockverse/core/utils/paged.dart';
import 'package:blockverse/core/utils/time_ago.dart';
import 'package:blockverse/features/home/domain/post.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake extends PagedNotifier<int> {
  _Fake(this.total);
  final int total;

  @override
  int get pageSize => 3;

  @override
  Future<List<int>> fetchPage(int? last) async {
    final start = (last ?? -1) + 1;
    return [for (var i = start; i < total && i < start + 3; i++) i];
  }
}

void main() {
  test('PagedNotifier loads pages until exhausted', () async {
    final n = _Fake(7);
    await Future<void>.delayed(Duration.zero);
    expect(n.state.items, [0, 1, 2]);
    expect(n.state.hasMore, isTrue);

    await n.loadMore();
    expect(n.state.items.length, 6);

    await n.loadMore();
    expect(n.state.items.length, 7);
    expect(n.state.hasMore, isFalse);

    await n.loadMore(); // no-op once exhausted
    expect(n.state.items.length, 7);
    n.dispose();
  });

  test('Post.fromMap parses media and copyWith updates like state', () {
    final p = Post.fromMap({
      'id': 'p1', 'author_id': 'u1', 'content': 'hi',
      'created_at': '2026-05-01T10:00:00.123456Z',
      'username': 'alex', 'display_name': null,
      'author_role_key': 'creator',
      'media': [
        {'url': 'https://x/a.jpg', 'kind': 'image'},
        {'url': 'https://x/b.jpg', 'kind': 'image'},
      ],
      'likes_count': 2, 'comments_count': 1, 'liked_by_me': false,
    });
    expect(p.displayName, 'alex');
    expect(p.media.length, 2);
    final liked = p.copyWith(likedByMe: true, likesCount: 3);
    expect(liked.likedByMe, isTrue);
    expect(liked.likesCount, 3);
    expect(liked.commentsCount, 1);
  });

  test('timeAgo buckets', () {
    final now = DateTime.utc(2026, 5, 1, 12);
    expect(timeAgo(now.subtract(const Duration(seconds: 10)), now: now), 'now');
    expect(timeAgo(now.subtract(const Duration(minutes: 5)), now: now), '5m');
    expect(timeAgo(now.subtract(const Duration(hours: 3)), now: now), '3h');
    expect(timeAgo(now.subtract(const Duration(days: 2)), now: now), '2d');
  });
}
