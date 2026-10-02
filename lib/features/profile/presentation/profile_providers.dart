import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/domain/post.dart';
import '../../home/presentation/post_providers.dart';

import '../data/profile_repository.dart';
import '../domain/profile_details.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((_) => ProfileRepository());

final profileByUsernameProvider =
    FutureProvider.autoDispose.family<ProfileDetails?, String>(
  (ref, username) => ref.watch(profileRepositoryProvider).fetchByUsername(username),
);

final userPostsProvider =
    FutureProvider.autoDispose.family<List<Post>, String>((ref, userId) {
  return ref.watch(postRepositoryProvider).fetchUserPosts(userId);
});

final likedPostsProvider =
    FutureProvider.autoDispose.family<List<Post>, String>((ref, userId) {
  return ref.watch(postRepositoryProvider).fetchLikedPosts(userId);
});
