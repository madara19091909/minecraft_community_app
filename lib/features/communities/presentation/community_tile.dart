import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../domain/community.dart';
import 'community_avatar.dart';

class CommunityTile extends StatelessWidget {
  const CommunityTile({super.key, required this.community});
  final Community community;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = community;
    final subtitle = [
      '${c.memberCount} ${c.memberCount == 1 ? 'member' : 'members'}',
      if (c.description != null && c.description!.trim().isNotEmpty) c.description!.trim(),
    ].join(' · ');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CommunityAvatar(url: c.iconUrl),
      title: Row(children: [
        Flexible(
          child: Text(c.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        if (c.isPrivate) ...[
          const SizedBox(width: 6),
          Icon(Icons.lock, size: 14, color: t.hintColor),
        ],
      ]),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: c.isMember
          ? Icon(Icons.check_circle, color: t.colorScheme.primary, size: 20)
          : c.isPending
              ? Text('Requested', style: TextStyle(color: t.hintColor, fontSize: 12))
              : null,
      onTap: () => context.push(Routes.community(c.id)),
    );
  }
}
