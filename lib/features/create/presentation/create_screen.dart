import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/picked_image.dart';
import '../../communities/presentation/community_providers.dart';
import '../../home/presentation/post_providers.dart';

class CreateScreen extends ConsumerStatefulWidget {
  const CreateScreen({super.key});

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  static const _maxImages = 4;
  final _text = TextEditingController();
  final _picker = ImagePicker();
  final _images = <PickedImage>[];
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _addImages() async {
    final room = _maxImages - _images.length;
    if (room <= 0) return;
    final files = await _picker.pickMultiImage(maxWidth: 1600, imageQuality: 80, limit: room);
    for (final f in files.take(room)) {
      final name = f.name.toLowerCase();
      final ext = name.endsWith('.png') ? 'png' : name.endsWith('.webp') ? 'webp' : 'jpg';
      _images.add(PickedImage(await f.readAsBytes(), ext));
    }
    if (mounted) setState(() {});
  }

  Future<void> _publish() async {
    final text = _text.text.trim();
    if (text.isEmpty && _images.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Write something or add a photo.')));
      return;
    }
    setState(() => _busy = true);
    try {
      final communityId = ref.read(composeCommunityProvider);
      await ref.read(postRepositoryProvider).createPost(
            content: text,
            images: List.of(_images),
            communityId: communityId,
          );
      ref.read(feedProvider.notifier).refresh();
      ref.invalidate(communityFeedProvider);
      ref.read(composeCommunityProvider.notifier).state = null;
      _text.clear();
      _images.clear();
      if (mounted) {
        context.go(Routes.home);
        if (communityId != null) context.push(Routes.community(communityId));
      }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('New post'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(84, 40)),
              onPressed: _busy ? null : _publish,
              child: _busy
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Post'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _text,
            minLines: 5,
            maxLines: null,
            maxLength: 2000,
            enabled: !_busy,
            decoration: const InputDecoration(hintText: "What's happening in your world?"),
          ),
          const SizedBox(height: 12),
          _CommunityPicker(enabled: !_busy),
          const SizedBox(height: 12),
          if (_images.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _images.length; i++)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(_images[i].bytes, width: 96, height: 96, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: _busy ? null : () => setState(() => _images.removeAt(i)),
                          child: const CircleAvatar(
                            radius: 11,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: (_busy || _images.length >= _maxImages) ? null : _addImages,
              icon: const Icon(Icons.image_outlined),
              label: Text('Add photos (${_images.length}/$_maxImages)'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityPicker extends ConsumerWidget {
  const _CommunityPicker({required this.enabled});
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communities = ref.watch(myCommunitiesProvider).valueOrNull ?? const [];
    final selected = ref.watch(composeCommunityProvider);
    final value = communities.any((c) => c.id == selected) ? selected : null;
    return DropdownButtonFormField<String?>(
      value: value,
      decoration: const InputDecoration(labelText: 'Post to', prefixIcon: Icon(Icons.groups_outlined)),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Everyone (main feed)')),
        for (final c in communities)
          DropdownMenuItem<String?>(
            value: c.id,
            child: Text(c.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: enabled ? (v) => ref.read(composeCommunityProvider.notifier).state = v : null,
    );
  }
}
