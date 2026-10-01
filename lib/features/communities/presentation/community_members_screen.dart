import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/community.dart';
import '../domain/community_member.dart';
import 'community_providers.dart';

class CommunityMembersScreen extends ConsumerWidget {
  const CommunityMembersScreen({super.key, required this.communityId});
  final String communityId;

  Future<void> _addMember(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final username = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add member'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Username', prefixText: '@'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Add')),
        ],
      ),
    );
    ctrl.dispose();
    if (username == null || username.trim().isEmpty) return;
    try {
      await ref.read(communityRepositoryProvider).addMember(communityId, username);
      ref.invalidate(membersProvider((communityId, 'active')));
      ref.invalidate(communityProvider(communityId));
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(communityProvider(communityId));
    final c = async.valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      floatingActionButton: (c != null && c.canManage)
          ? FloatingActionButton.extended(
              onPressed: () => _addMember(context, ref),
              icon: const Icon(Icons.person_add),
              label: const Text('Add'),
            )
          : null,
      body: async.when(
        skipLoadingOnReload: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: AppFailure.from(e).message,
          onRetry: () => ref.invalidate(communityProvider(communityId)),
        ),
        data: (c) => c == null
            ? const EmptyView(icon: Icons.search_off, title: 'Community not found')
            : _MembersList(community: c),
      ),
    );
  }
}

class _MembersList extends ConsumerWidget {
  const _MembersList({required this.community});
  final Community community;

  /// Roles the current user may assign / whether they may remove the target.
  ({List<String> roles, bool canRemove}) _powers(String? myRole, CommunityMember target, bool isSelf) {
    if (isSelf || target.role == 'owner' || myRole == null) return (roles: const [], canRemove: false);
    switch (myRole) {
      case 'owner':
        return (roles: const ['admin', 'moderator', 'member'], canRemove: true);
      case 'admin':
        return target.role == 'admin'
            ? (roles: const [], canRemove: false)
            : (roles: const ['moderator', 'member'], canRemove: true);
      case 'moderator':
        return (roles: const [], canRemove: target.role == 'member');
      default:
        return (roles: const [], canRemove: false);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = community;
    final myId = ref.watch(authControllerProvider.select((a) => a.profile?.id));
    final repo = ref.read(communityRepositoryProvider);
    final activeKey = (c.id, 'active');
    final pendingKey = (c.id, 'pending');
    final active = ref.watch(membersProvider(activeKey));
    final activeCtrl = ref.read(membersProvider(activeKey).notifier);
    final pending = c.canModerate ? ref.watch(membersProvider(pendingKey)) : null;
    final pendingCtrl = c.canModerate ? ref.read(membersProvider(pendingKey).notifier) : null;

    Future<void> guarded(Future<void> Function() fn) async {
      try {
        await fn();
      } catch (e) {
        if (context.mounted) showErrorSnack(context, e);
      }
    }

    Widget section(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
          child: Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).hintColor,
                  letterSpacing: 0.4)),
        );

    if (active.isLoading) return const LoadingView();
    if (active.error != null && active.items.isEmpty) {
      return ErrorView(message: active.error!, onRetry: activeCtrl.refresh);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await activeCtrl.refresh();
        await pendingCtrl?.refresh();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          if (pending != null && pending.items.isNotEmpty) ...[
            section('REQUESTS (${pending.items.length})'),
            for (final m in pending.items)
              ListTile(
                leading: GestureDetector(
                  onTap: () => context.push(Routes.user(m.username)),
                  child: UserAvatar(url: m.avatarUrl, radius: 20),
                ),
                title: Text(m.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('@${m.username}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: 'Reject',
                    icon: const Icon(Icons.close),
                    onPressed: () => guarded(() async {
                      await repo.removeMember(c.id, m.userId);
                      pendingCtrl!.removeLocal(m.userId);
                    }),
                  ),
                  IconButton(
                    tooltip: 'Approve',
                    icon: Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                    onPressed: () => guarded(() async {
                      await repo.approve(c.id, m.userId);
                      pendingCtrl!.removeLocal(m.userId);
                      await activeCtrl.refresh();
                      ref.invalidate(communityProvider(c.id));
                    }),
                  ),
                ]),
              ),
          ],
          section('MEMBERS (${c.memberCount})'),
          for (final m in active.items)
            _MemberTile(
              member: m,
              powers: _powers(c.myRole, m, m.userId == myId),
              onRole: (role) => guarded(() async {
                await repo.setRole(c.id, m.userId, role);
                await activeCtrl.refresh();
              }),
              onRemove: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Remove ${m.displayName}?',
                  message: 'They will lose access to this community.',
                  confirmLabel: 'Remove',
                );
                if (!ok) return;
                await guarded(() async {
                  await repo.removeMember(c.id, m.userId);
                  activeCtrl.removeLocal(m.userId);
                  ref.invalidate(communityProvider(c.id));
                });
              },
            ),
          if (active.isLoadingMore)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          else if (active.hasMore)
            TextButton(onPressed: activeCtrl.loadMore, child: const Text('Load more')),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.powers,
    required this.onRole,
    required this.onRemove,
  });
  final CommunityMember member;
  final ({List<String> roles, bool canRemove}) powers;
  final void Function(String role) onRole;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final hasMenu = powers.roles.isNotEmpty || powers.canRemove;
    return ListTile(
      leading: GestureDetector(
        onTap: () => context.push(Routes.user(member.username)),
        child: UserAvatar(url: member.avatarUrl, radius: 20),
      ),
      title: Text(member.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
          '@${member.username}${member.role == 'member' ? '' : ' · ${member.role}'}',
          style: TextStyle(color: member.role == 'member' ? null : t.colorScheme.primary)),
      trailing: hasMenu
          ? PopupMenuButton<String>(
              onSelected: (v) => v == '_remove' ? onRemove() : onRole(v),
              itemBuilder: (_) => [
                for (final r in powers.roles)
                  if (r != member.role) PopupMenuItem(value: r, child: Text('Make $r')),
                if (powers.canRemove) const PopupMenuItem(value: '_remove', child: Text('Remove')),
              ],
            )
          : null,
    );
  }
}
