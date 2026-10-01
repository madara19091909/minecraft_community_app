import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profile_repository.dart';
import '../domain/profile_details.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((_) => ProfileRepository());

final profileByUsernameProvider =
    FutureProvider.autoDispose.family<ProfileDetails?, String>(
  (ref, username) => ref.watch(profileRepositoryProvider).fetchByUsername(username),
);
