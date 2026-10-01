import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../domain/post.dart';
import 'image_viewer.dart';

class PostMediaGrid extends StatelessWidget {
  const PostMediaGrid({super.key, required this.media});
  final List<PostMedia> media;

  @override
  Widget build(BuildContext context) {
    final n = media.length;
    if (n == 0) return const SizedBox.shrink();
    final urls = [for (final m in media) m.url];

    Widget tile(int i) => GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ImageViewerScreen(urls: urls, initialIndex: i),
          )),
          child: CachedNetworkImage(
            imageUrl: urls[i],
            fit: BoxFit.cover,
            memCacheWidth: 900,
            placeholder: (_, __) =>
                ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest),
            errorWidget: (_, __, ___) => ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image),
            ),
          ),
        );

    const gap = SizedBox(width: 4, height: 4);
    final Widget body;
    if (n == 1) {
      body = AspectRatio(aspectRatio: 4 / 3, child: SizedBox.expand(child: tile(0)));
    } else if (n == 2) {
      body = SizedBox(
        height: 240,
        child: Row(children: [Expanded(child: tile(0)), gap, Expanded(child: tile(1))]),
      );
    } else if (n == 3) {
      body = SizedBox(
        height: 260,
        child: Row(children: [
          Expanded(child: tile(0)),
          gap,
          Expanded(
            child: Column(children: [Expanded(child: tile(1)), gap, Expanded(child: tile(2))]),
          ),
        ]),
      );
    } else {
      body = SizedBox(
        height: 260,
        child: Column(children: [
          Expanded(child: Row(children: [Expanded(child: tile(0)), gap, Expanded(child: tile(1))])),
          gap,
          Expanded(child: Row(children: [Expanded(child: tile(2)), gap, Expanded(child: tile(3))])),
        ]),
      );
    }
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: body);
  }
}
