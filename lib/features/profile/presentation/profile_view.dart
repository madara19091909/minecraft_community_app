import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/profile_details.dart';
import '../../messages/presentation/message_providers.dart';
import 'follow_button.dart';
import 'profile_providers.dart';

/// Shared by the Profile tab (own profile) and /u/:username (anyone).
class ProfileView extends ConsumerWidget {
  const ProfileView({super.key, required this.username});
  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = profileByUsernameProvider(username);
    final myId = ref.watch(authControllerProvider.select((a) => a.profile?.id));

    return ref.watch(provider).when(
          skipLoadingOnReload: true,
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: AppFailure.from(e).message,
            onRetry: () => ref.invalidate(provider),
          ),
          data: (p) => p == null
              ? const EmptyView(icon: Icons.person_off, title: 'User not found')
              : RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(provider);
                    await ref.read(provider.future);
                  },
                  child: _Body(profile: p, isMe: p.id == myId),
                ),
        );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.profile, required this.isMe});
  final ProfileDetails profile;
  final bool isMe;

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = profile;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        _Header(profile: p),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.displayName,
                            style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                        Text('@${p.username}', style: TextStyle(color: t.hintColor)),
                      ],
                    ),
                  ),
                  if (isMe)
                    OutlinedButton.icon(
                      onPressed: () => context.push(Routes.editProfile),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                    )
                  else
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      _MessageButton(userId: p.id),
                      const SizedBox(width: 8),
                      FollowButton(profile: p),
                    ]),
                ],
              ),
              const SizedBox(height: 10),
              _RoleChip(roleKey: p.roleKey, roleName: p.roleName),
              if (p.isRestricted) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Icon(Icons.lock_outline, size: 16, color: t.hintColor),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text('Only followers can see the full profile.',
                        style: TextStyle(color: t.hintColor)),
                  ),
                ]),
              ],
              if (p.bio != null && p.bio!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(p.bio!),
              ],
              if (p.minecraftUsername != null && p.minecraftUsername!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Icon(Icons.sports_esports, size: 18, color: t.colorScheme.primary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      p.minecraftUsername! +
                          (p.editionLabel.isEmpty ? '' : '  ·  ${p.editionLabel}'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              ],
              const SizedBox(height: 16),
              Row(children: [
                _Stat(value: p.followersCount, label: 'Followers'),
                const SizedBox(width: 28),
                _Stat(value: p.followingCount, label: 'Following'),
              ]),
              if (p.links.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final e in p.links.entries) _LinkChip(kind: e.key, value: e.value)],
                ),
              ],
              const SizedBox(height: 16),
              Text('Joined ${_months[p.createdAt.month - 1]} ${p.createdAt.year}',
                  style: TextStyle(color: t.hintColor, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});
  final ProfileDetails profile;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return SizedBox(
      height: 176,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0, right: 0, top: 0, height: 130,
            child: profile.bannerUrl == null
                ? const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.grassDark, AppColors.dirt],
                      ),
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: profile.bannerUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 1200,
                    errorWidget: (_, __, ___) => const ColoredBox(color: AppColors.surfaceHighDark),
                  ),
          ),
          Positioned(
            left: 16, bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
              child: UserAvatar(url: profile.avatarUrl, radius: 42),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.roleKey, required this.roleName});
  final String roleKey;
  final String roleName;

  @override
  Widget build(BuildContext context) {
    final color = switch (roleKey) {
      'owner' => AppColors.gold,
      'admin' => AppColors.redstone,
      'moderator' => AppColors.diamond,
      'creator' => AppColors.grass,
      _ => Theme.of(context).hintColor,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(roleName,
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          Text(label, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
        ],
      );
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.kind, required this.value});
  final String kind;
  final String value;

  IconData get _icon => switch (kind) {
        'youtube' => Icons.smart_display,
        'tiktok' => Icons.music_note,
        'discord' => Icons.forum,
        _ => Icons.link,
      };

  Future<void> _open(BuildContext context) async {
    if (kind == 'discord') {
      await Clipboard.setData(ClipboardData(text: value));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Discord copied')));
      }
      return;
    }
    final ok = await launchUrl(Uri.parse(Validators.normalizeUrl(value)),
        mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not open link')));
    }
  }

  @override
  Widget build(BuildContext context) => ActionChip(
        avatar: Icon(_icon, size: 18),
        label: Text(kind == 'discord' ? value : kind[0].toUpperCase() + kind.substring(1)),
        onPressed: () => _open(context),
      );
}

class _MessageButton extends ConsumerStatefulWidget {
  const _MessageButton({required this.userId});
  final String userId;

  @override
  ConsumerState<_MessageButton> createState() => _MessageButtonState();
}

class _MessageButtonState extends ConsumerState<_MessageButton> {
  bool _busy = false;

  Future<void> _open() async {
    setState(() => _busy = true);
    try {
      final id = await ref.read(messageRepositoryProvider).startDirect(widget.userId);
      if (mounted) context.push(Routes.chat(id));
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton.outlined(
        tooltip: 'Message',
        onPressed: _busy ? null : _open,
        icon: _busy
            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.chat_bubble_outline),
      );
}
