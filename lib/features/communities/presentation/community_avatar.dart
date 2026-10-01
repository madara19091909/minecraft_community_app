import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Rounded-square icon (communities look different from round user avatars).
class CommunityAvatar extends StatelessWidget {
  const CommunityAvatar({super.key, this.url, this.size = 48});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Icon(Icons.groups, size: size * 0.55, color: scheme.primary),
    );
    if (url == null || url!.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.25),
      child: CachedNetworkImage(
        imageUrl: url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: (size * 3).round(),
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}
