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
import '../../home/data/post_repository.dart';
import '../../home/domain/post.dart';
import '../../home/presentation/post_card.dart';
import '../../home/presentation/post_providers.dart';
import '../../messages/presentation/message_providers.dart';
import '../domain/profile_details.dart';
import 'follow_button.dart';
import 'profile_providers.dart';

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
          : _ProfilePage(profile: p, isMe: p.id == myId),
    );
  }
}

class _ProfilePage extends ConsumerStatefulWidget {
  const _ProfilePage({required this.profile, required this.isMe});
  final ProfileDetails profile;
  final bool isMe;

  @override
  ConsumerState<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<_ProfilePage> {
  Future<void> _refresh() async {
    ref.invalidate(profileByUsernameProvider(widget.profile.username));
    await ref.read(profileByUsernameProvider(widget.profile.username).future);
    ref.invalidate(userPostsProvider(widget.profile.id));
    ref.invalidate(likedPostsProvider(widget.profile.id));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return DefaultTabController(
      length: 4,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  _HeroHeader(profile: p),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _Identity(profile: p, isMe: widget.isMe),
                  ),
                  _ProfileTabs(profile: p, isMe: widget.isMe),
                ],
              ),
            ),
            // Kept below the compact identity so the full profile can scroll naturally.
          ],
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.profile});
  final ProfileDetails profile;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final roleColor = _roleColor(profile.roleKey);
    return SizedBox(
      height: 238,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: profile.bannerUrl == null
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.grassDark, AppColors.dirt, roleColor.withValues(alpha: .55)],
                      ),
                    ),
                    child: CustomPaint(painter: _BlockPatternPainter()),
                  )
                : CachedNetworkImage(
                    imageUrl: profile.bannerUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 1400,
                    errorWidget: (_, __, ___) => const DecoratedBox(
                      decoration: BoxDecoration(color: AppColors.surfaceHighDark),
                    ),
                  ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: .05), Colors.black.withValues(alpha: .48)],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bg,
                boxShadow: const [BoxShadow(blurRadius: 18, offset: Offset(0, 7))],
              ),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: roleColor, width: 2.5)),
                child: UserAvatar(url: profile.avatarUrl, radius: 52),
              ),
            ),
          ),
          Positioned(
            left: 18,
            top: 14,
            child: _MinecraftPill(profile: profile),
          ),
          Positioned(
            right: 14,
            bottom: 14,
            child: _RoleBadge(roleKey: profile.roleKey, roleName: profile.roleName),
          ),
        ],
      ),
    );
  }
}

class _MinecraftPill extends StatelessWidget {
  const _MinecraftPill({required this.profile});
  final ProfileDetails profile;
  @override
  Widget build(BuildContext context) {
    if ((profile.minecraftUsername ?? '').trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .58),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: .25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.sports_esports, color: Colors.white, size: 16),
        const SizedBox(width: 6),
        Text(profile.minecraftUsername!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
        if (profile.editionLabel.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text('• ${profile.editionLabel.replaceAll(' Edition', '')}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ]),
    );
  }
}

class _BlockPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: .045);
    const s = 28.0;
    for (double y = 0; y < size.height; y += s) {
      for (double x = 0; x < size.width; x += s) {
        if (((x / s).floor() + (y / s).floor()) % 2 == 0) {
          canvas.drawRect(Rect.fromLTWH(x, y, s, s), p);
        }
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Identity extends StatelessWidget {
  const _Identity({required this.profile, required this.isMe});
  final ProfileDetails profile;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final roleColor = _roleColor(profile.roleKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(profile.displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                ),
                if (profile.roleKey != 'member') ...[
                  const SizedBox(width: 6),
                  Icon(Icons.verified, size: 20, color: roleColor),
                ],
              ]),
              GestureDetector(
                onLongPress: () async {
                  await Clipboard.setData(ClipboardData(text: '@${profile.username}'));
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username copied')));
                },
                child: Text('@${profile.username}', style: TextStyle(color: t.hintColor)),
              ),
            ]),
          ),
          if (isMe)
            OutlinedButton.icon(
              onPressed: () => context.push(Routes.editProfile),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            )
          else
            Row(mainAxisSize: MainAxisSize.min, children: [
              _MessageButton(userId: profile.id),
              const SizedBox(width: 7),
              FollowButton(profile: profile),
            ]),
        ]),
        if (profile.bio?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 12),
          Text(profile.bio!, style: const TextStyle(height: 1.42, fontSize: 14.5)),
        ],
        const SizedBox(height: 14),
        _QuickFacts(profile: profile),
        const SizedBox(height: 14),
        _Stats(profile: profile),
        const SizedBox(height: 14),
        _MinecraftCard(profile: profile),
        if (profile.links.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Links(profile: profile),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Icon(Icons.calendar_month_outlined, size: 16, color: t.hintColor),
          const SizedBox(width: 6),
          Text('Joined ${_month(profile.createdAt.month)} ${profile.createdAt.year}', style: TextStyle(color: t.hintColor, fontSize: 13)),
        ]),
      ],
    );
  }
}

class _QuickFacts extends StatelessWidget {
  const _QuickFacts({required this.profile});
  final ProfileDetails profile;
  @override
  Widget build(BuildContext context) {
    final facts = <String>[
      if (profile.roleKey != 'member') profile.roleName,
      if (profile.minecraftUsername?.trim().isNotEmpty == true) 'Minecraft player',
      if (profile.links.isNotEmpty) '${profile.links.length} links',
    ];
    if (facts.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 7, runSpacing: 7, children: [
      for (final fact in facts)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(fact, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
        ),
    ]);
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.profile});
  final ProfileDetails profile;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(value: profile.followersCount, label: 'Followers', icon: Icons.people_alt_outlined),
              _Stat(value: profile.followingCount, label: 'Following', icon: Icons.person_add_alt_1_outlined),
              _Stat(value: profile.roleKey == 'member' ? 0 : 1, label: 'Badges', icon: Icons.workspace_premium_outlined),
            ],
          ),
        ),
      );
}

class _MinecraftCard extends StatelessWidget {
  const _MinecraftCard({required this.profile});
  final ProfileDetails profile;

  @override
  Widget build(BuildContext context) {
    if ((profile.minecraftUsername ?? '').trim().isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [t.colorScheme.primaryContainer, t.cardColor],
        ),
        border: Border.all(color: t.colorScheme.primary.withValues(alpha: .25)),
      ),
      child: Row(children: [
        const Icon(Icons.sports_esports_outlined, size: 30),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Minecraft profile', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(profile.minecraftUsername!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          if (profile.editionLabel.isNotEmpty)
            Text(profile.editionLabel, style: TextStyle(color: t.hintColor, fontSize: 12)),
        ])),
        const Icon(Icons.chevron_right),
      ]),
    );
  }
}

class _Links extends StatelessWidget {
  const _Links({required this.profile});
  final ProfileDetails profile;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final e in profile.links.entries) _LinkChip(kind: e.key, value: e.value)],
      );
}

class _ProfileTabs extends ConsumerWidget {
  const _ProfileTabs({required this.profile, required this.isMe});
  final ProfileDetails profile;
  final bool isMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = DefaultTabController.of(context);
    return Column(
      children: [
        TabBar(
          controller: controller,
          isScrollable: false,
          tabs: const [
            Tab(icon: Icon(Icons.person_outline), text: 'About'),
            Tab(icon: Icon(Icons.grid_view_outlined), text: 'Posts'),
            Tab(icon: Icon(Icons.favorite_border), text: 'Liked'),
            Tab(icon: Icon(Icons.emoji_events_outlined), text: 'Badges'),
          ],
        ),
        SizedBox(
          height: 520,
          child: TabBarView(
            controller: controller,
            children: [
              _AboutTab(profile: profile),
              _PostsTab(profile: profile),
              _LikedTab(profile: profile, isMe: isMe),
              _BadgesTab(profile: profile),
            ],
          ),
        ),
      ],
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.profile});
  final ProfileDetails profile;
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          if (profile.minecraftUsername?.trim().isNotEmpty == true)
            _InfoTile(icon: Icons.sports_esports_outlined, title: 'Minecraft identity', subtitle: '${profile.minecraftUsername}${profile.editionLabel.isNotEmpty ? ' • ${profile.editionLabel}' : ''}'),
          _InfoTile(icon: Icons.shield_outlined, title: 'Blockverse role', subtitle: '${profile.roleName} • rank and permissions are managed by the Blockverse team.'),
          _InfoTile(icon: Icons.people_alt_outlined, title: 'Community', subtitle: '${profile.followersCount} followers • following ${profile.followingCount} people.'),
          _InfoTile(icon: Icons.link_outlined, title: 'Connected links', subtitle: profile.links.isEmpty ? 'No external links added yet.' : '${profile.links.length} external links connected.'),
          const _InfoTile(icon: Icons.security_outlined, title: 'Privacy', subtitle: 'Profile visibility, blocking and account controls are available in Settings.'),
        ],
      );
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 5),
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
      );
}

class _PostsTab extends ConsumerWidget {
  const _PostsTab({required this.profile});
  final ProfileDetails profile;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(userPostsProvider(profile.id)).when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: AppFailure.from(e).message),
      data: (posts) => posts.isEmpty
          ? const EmptyView(icon: Icons.grid_view_outlined, title: 'No posts yet')
          : ListView.separated(
              padding: const EdgeInsets.only(top: 6, bottom: 24),
              itemCount: posts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => _ProfilePost(post: posts[i]),
            ),
    );
  }
}

class _LikedTab extends ConsumerWidget {
  const _LikedTab({required this.profile, required this.isMe});
  final ProfileDetails profile;
  final bool isMe;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isMe) {
      return const EmptyView(icon: Icons.lock_outline, title: 'Liked posts are private');
    }
    return ref.watch(likedPostsProvider(profile.id)).when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: AppFailure.from(e).message),
      data: (posts) => posts.isEmpty
          ? const EmptyView(icon: Icons.favorite_border, title: 'No liked posts')
          : ListView.separated(
              padding: const EdgeInsets.only(top: 6, bottom: 24),
              itemCount: posts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => _ProfilePost(post: posts[i]),
            ),
    );
  }
}

class _ProfilePost extends ConsumerWidget {
  const _ProfilePost({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PostCard(
      post: post,
      onLike: () async {
        try {
          if (post.likedByMe) {
            await ref.read(postRepositoryProvider).unlike(post.id);
          } else {
            await ref.read(postRepositoryProvider).like(post.id);
          }
          ref.invalidate(userPostsProvider(post.authorId));
          ref.invalidate(likedPostsProvider(post.authorId));
        } catch (e) {
          if (context.mounted) showErrorSnack(context, e);
        }
      },
      onDelete: () async {
        try {
          await ref.read(postRepositoryProvider).deletePost(post.id);
          ref.invalidate(userPostsProvider(post.authorId));
        } catch (e) {
          if (context.mounted) showErrorSnack(context, e);
        }
      },
      onOpen: () => context.push(Routes.post(post.id)),
    );
  }
}

class _BadgesTab extends StatelessWidget {
  const _BadgesTab({required this.profile});
  final ProfileDetails profile;
  @override
  Widget build(BuildContext context) {
    final badges = <_Badge>[
      if (profile.roleKey != 'member') _Badge('Verified role', Icons.verified, 'Official Blockverse role'),
      if (profile.minecraftUsername?.isNotEmpty == true)
        _Badge('Minecraft player', Icons.sports_esports, 'Minecraft identity added'),
      if (profile.links.isNotEmpty) _Badge('Creator links', Icons.link, 'External links connected'),
      _Badge('Blockverse member', Icons.cube_outlined, 'Profile created on Blockverse'),
    ];
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: badges.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.18,
      ),
      itemBuilder: (_, i) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(badges[i].icon, size: 34, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(badges[i].title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(badges[i].subtitle, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 11)),
          ]),
        ),
      ),
    );
  }
}

class _Badge {
  const _Badge(this.title, this.icon, this.subtitle);
  final String title;
  final IconData icon;
  final String subtitle;
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.roleKey, required this.roleName});
  final String roleKey;
  final String roleName;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .62),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _roleColor(roleKey).withValues(alpha: .75)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.shield, size: 16, color: _roleColor(roleKey)),
          const SizedBox(width: 6),
          Text(roleName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
        ]),
      );
}

Color _roleColor(String key) => switch (key) {
  'owner' => AppColors.gold,
  'admin' => AppColors.redstone,
  'moderator' => AppColors.diamond,
  'creator' => AppColors.grass,
  _ => Colors.white,
};

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.icon});
  final int value;
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
    const SizedBox(height: 4),
    Text('$value', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19)),
    Text(label, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
  ]);
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
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Discord copied')));
      return;
    }
    final ok = await launchUrl(Uri.parse(Validators.normalizeUrl(value)), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open link')));
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
  @override ConsumerState<_MessageButton> createState() => _MessageButtonState();
}
class _MessageButtonState extends ConsumerState<_MessageButton> {
  bool _busy = false;
  Future<void> _open() async {
    setState(() => _busy = true);
    try {
      final id = await ref.read(messageRepositoryProvider).startDirect(widget.userId);
      if (mounted) context.push(Routes.chat(id));
    } catch (e) { if (mounted) showErrorSnack(context, e); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => IconButton.outlined(
    tooltip: 'Message',
    onPressed: _busy ? null : _open,
    icon: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chat_bubble_outline),
  );
}

String _month(int m) => const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];

