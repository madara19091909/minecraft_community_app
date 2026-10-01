import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/profile_details.dart';
import 'profile_providers.dart';

class FollowButton extends ConsumerStatefulWidget {
  const FollowButton({super.key, required this.profile});
  final ProfileDetails profile;

  @override
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton> {
  bool _busy = false;

  Future<void> _toggle() async {
    final repo = ref.read(profileRepositoryProvider);
    final p = widget.profile;
    setState(() => _busy = true);
    try {
      p.isFollowing ? await repo.unfollow(p.id) : await repo.follow(p.id);
      ref.invalidate(profileByUsernameProvider(p.username));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppFailure.from(e).message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final following = widget.profile.isFollowing;
    final child = _busy
        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : Text(following ? 'Following' : 'Follow');
    return following
        ? OutlinedButton(onPressed: _busy ? null : _toggle, child: child)
        : FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            onPressed: _busy ? null : _toggle,
            child: child,
          );
  }
}
