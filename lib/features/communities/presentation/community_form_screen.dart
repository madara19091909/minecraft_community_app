import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/picked_image.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../domain/community.dart';
import 'community_avatar.dart';
import 'community_providers.dart';

/// Create (communityId == null) or edit a community.
class CommunityFormScreen extends ConsumerWidget {
  const CommunityFormScreen({super.key, this.communityId});
  final String? communityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = communityId;
    return Scaffold(
      appBar: AppBar(title: Text(id == null ? 'New community' : 'Edit community')),
      body: id == null
          ? const _Form()
          : ref.watch(communityProvider(id)).when(
                skipLoadingOnReload: true,
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(
                  message: AppFailure.from(e).message,
                  onRetry: () => ref.invalidate(communityProvider(id)),
                ),
                data: (c) => c == null
                    ? const ErrorView(message: 'Community not found')
                    : c.canManage
                        ? _Form(initial: c)
                        : const ErrorView(message: "You can't edit this community."),
              ),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({this.initial});
  final Community? initial;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _desc = TextEditingController(text: widget.initial?.description ?? '');
  late final _rules = TextEditingController(text: widget.initial?.rules ?? '');
  late String _privacy = widget.initial?.privacy ?? 'public';
  PickedImage? _icon;
  PickedImage? _banner;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _rules.dispose();
    super.dispose();
  }

  String? _nullIfEmpty(String v) => v.trim().isEmpty ? null : v.trim();

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _busy = true);
    final repo = ref.read(communityRepositoryProvider);
    try {
      final initial = widget.initial;
      if (initial == null) {
        final id = await repo.create(
          name: _name.text,
          description: _nullIfEmpty(_desc.text),
          rules: _nullIfEmpty(_rules.text),
          privacy: _privacy,
          icon: _icon,
          banner: _banner,
        );
        ref.invalidate(myCommunitiesProvider);
        ref.invalidate(discoverProvider);
        if (mounted) context.pushReplacement(Routes.community(id));
      } else {
        await repo.update(
          initial,
          name: _name.text,
          description: _nullIfEmpty(_desc.text),
          rules: _nullIfEmpty(_rules.text),
          privacy: _privacy,
          icon: _icon,
          banner: _banner,
        );
        refreshCommunityData(ref, initial.id);
        if (mounted) context.pop();
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final initial = widget.initial;

    return Form(
      key: _key,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: _busy
                ? null
                : () async {
                    final img = await pickSingleImage(maxWidth: 1600);
                    if (img != null) setState(() => _banner = img);
                  },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 3,
                child: Stack(fit: StackFit.expand, children: [
                  if (_banner != null)
                    Image.memory(_banner!.bytes, fit: BoxFit.cover)
                  else if (initial?.bannerUrl != null)
                    CachedNetworkImage(imageUrl: initial!.bannerUrl!, fit: BoxFit.cover)
                  else
                    ColoredBox(color: scheme.surfaceContainerHighest),
                  const Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircleAvatar(radius: 14, child: Icon(Icons.camera_alt, size: 16)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: GestureDetector(
              onTap: _busy
                  ? null
                  : () async {
                      final img = await pickSingleImage(maxWidth: 512);
                      if (img != null) setState(() => _icon = img);
                    },
              child: Stack(alignment: Alignment.bottomRight, children: [
                _icon != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.memory(_icon!.bytes, width: 72, height: 72, fit: BoxFit.cover),
                      )
                    : CommunityAvatar(url: initial?.iconUrl, size: 72),
                CircleAvatar(
                  radius: 12,
                  backgroundColor: scheme.primary,
                  child: const Icon(Icons.camera_alt, size: 14, color: Colors.black),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _name,
            maxLength: 40,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (v) =>
                (v == null || v.trim().length < 3) ? 'At least 3 characters' : null,
          ),
          TextFormField(
            controller: _desc,
            maxLines: 3,
            maxLength: 300,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          TextFormField(
            controller: _rules,
            maxLines: 5,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: 'Rules', alignLabelWithHint: true),
          ),
          const SizedBox(height: 10),
          Text('Privacy', style: t.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'public', icon: Icon(Icons.public), label: Text('Public')),
              ButtonSegment(value: 'private', icon: Icon(Icons.lock), label: Text('Private')),
            ],
            selected: {_privacy},
            onSelectionChanged: _busy ? null : (s) => setState(() => _privacy = s.first),
          ),
          const SizedBox(height: 8),
          Text(
            _privacy == 'public'
                ? 'Anyone approved in the app can join instantly and read posts.'
                : 'People must request to join. Posts and members are hidden until approved.',
            style: TextStyle(color: t.hintColor, fontSize: 13),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : Text(initial == null ? 'Create community' : 'Save changes'),
          ),
        ],
      ),
    );
  }
}
