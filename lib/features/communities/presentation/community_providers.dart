import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/paged.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../home/domain/post.dart';
import '../../home/presentation/post_providers.dart';
import '../data/community_repository.dart';
import '../domain/community.dart';
import '../domain/community_member.dart';

final communityRepositoryProvider = Provider<CommunityRepository>((_) => CommunityRepository());

/// Community the compose screen will post into (null = no community).
final composeCommunityProvider = StateProvider<String?>((_) => null);

final canCreateCommunityProvider = FutureProvider<bool>((ref) {
  ref.watch(authControllerProvider.select((a) => a.profile?.id));
  return ref.watch(communityRepositoryProvider).hasPermission('communities.create');
});

final myCommunitiesProvider = FutureProvider<List<Community>>((ref) {
  ref.watch(authControllerProvider.select((a) => a.profile?.id));
  return ref.watch(communityRepositoryProvider).fetchMine();
});

final communityProvider = FutureProvider.autoDispose.family<Community?, String>(
  (ref, id) => ref.watch(communityRepositoryProvider).fetchById(id),
);

class DiscoverController extends PagedNotifier<Community> {
  DiscoverController(this._repo, this._query);
  final CommunityRepository _repo;
  final String _query;

  @override
  Future<List<Community>> fetchPage(Community? last) =>
      _repo.fetchDiscover(query: _query, before: last?.createdAt, limit: pageSize);
}

final discoverProvider = StateNotifierProvider.autoDispose
    .family<DiscoverController, PagedState<Community>, String>(
  (ref, query) => DiscoverController(ref.watch(communityRepositoryProvider), query),
);

class MembersController extends PagedNotifier<CommunityMember> {
  MembersController(this._repo, this._communityId, this._status);
  final CommunityRepository _repo;
  final String _communityId;
  final String _status;

  @override
  int get pageSize => 50;

  @override
  Future<List<CommunityMember>> fetchPage(CommunityMember? last) =>
      _repo.fetchMembers(_communityId, _status, after: last?.joinedAt, limit: pageSize);

  void removeLocal(String userId) => mutate((l) => l.where((m) => m.userId != userId).toList());
}

/// Family key: (communityId, 'active' | 'pending').
final membersProvider = StateNotifierProvider.autoDispose
    .family<MembersController, PagedState<CommunityMember>, (String, String)>(
  (ref, key) => MembersController(ref.watch(communityRepositoryProvider), key.$1, key.$2),
);

final communityFeedProvider =
    StateNotifierProvider.autoDispose.family<FeedController, PagedState<Post>, String>(
  (ref, communityId) =>
      FeedController(ref.watch(postRepositoryProvider), communityId: communityId),
);

/// Call after anything that changes membership/community data.
void refreshCommunityData(WidgetRef ref, String communityId) {
  ref.invalidate(communityProvider(communityId));
  ref.invalidate(myCommunitiesProvider);
  ref.invalidate(discoverProvider);
}
