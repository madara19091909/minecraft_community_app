import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/profile_repository.dart';
import '../domain/profile_details.dart';
import 'profile_providers.dart';

class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authControllerProvider.select((a) => a.profile));
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: me == null
          ? const LoadingView()
          : ref.watch(profileByUsernameProvider(me.username)).when(
                skipLoadingOnReload: true,
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(
                  message: AppFailure.from(e).message,
                  onRetry: () => ref.invalidate(profileByUsernameProvider(me.username)),
                ),
                data: (p) => p == null
                    ? const ErrorView(message: 'Profile not found')
                    : _EditForm(initial: p),
              ),
    );
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({required this.initial});
  final ProfileDetails initial;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  final _key = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late final _username = TextEditingController(text: widget.initial.username);
  late final _display = TextEditingController(
      text: widget.initial.displayName == widget.initial.username ? '' : widget.initial.displayName);
  late final _bio = TextEditingController(text: widget.initial.bio ?? '');
  late final _mc = TextEditingController(text: widget.initial.minecraftUsername ?? '');
  late final _youtube = TextEditingController(text: widget.initial.links['youtube'] ?? '');
  late final _tiktok = TextEditingController(text: widget.initial.links['tiktok'] ?? '');
  late final _discord = TextEditingController(text: widget.initial.links['discord'] ?? '');
  late final _website = TextEditingController(text: widget.initial.links['website'] ?? '');
  late String? _edition = widget.initial.minecraftEdition;

  PickedImage? _avatar;
  PickedImage? _banner;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_username, _display, _bio, _mc, _youtube, _tiktok, _discord, _website]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<PickedImage?> _pick({required double maxWidth}) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: maxWidth,
      imageQuality: 82, // client-side compression
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final name = file.name.toLowerCase();
    final ext = name.endsWith('.png') ? 'png' : name.endsWith('.webp') ? 'webp' : 'jpg';
    return PickedImage(bytes, ext);
  }

  String? _nullIfEmpty(String v) => v.trim().isEmpty ? null : v.trim();

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _busy = true);
    final repo = ref.read(profileRepositoryProvider);
    final auth = ref.read(authControllerProvider);
    final initial = widget.initial;
    try {
      var avatarUrl = initial.avatarUrl;
      var bannerUrl = initial.bannerUrl;
      if (_avatar != null) {
        avatarUrl = await repo.uploadImage(bucket: 'avatars', userId: initial.id, image: _avatar!);
      }
      if (_banner != null) {
        bannerUrl = await repo.uploadImage(bucket: 'banners', userId: initial.id, image: _banner!);
      }
      final links = <String, String>{
        if (_nullIfEmpty(_youtube.text) != null) 'youtube': _youtube.text.trim(),
        if (_nullIfEmpty(_tiktok.text) != null) 'tiktok': _tiktok.text.trim(),
        if (_nullIfEmpty(_discord.text) != null) 'discord': _discord.text.trim(),
        if (_nullIfEmpty(_website.text) != null) 'website': _website.text.trim(),
      };
      await repo.updateProfile(initial.id, {
        'username': _username.text.trim().toLowerCase(),
        'display_name': _nullIfEmpty(_display.text),
        'bio': _nullIfEmpty(_bio.text),
        'minecraft_username': _nullIfEmpty(_mc.text),
        'minecraft_edition': _edition,
        'links': links,
        'avatar_url': avatarUrl,
        'banner_url': bannerUrl,
      });
      // Clean up replaced files only after the profile row points to the new ones.
      if (_avatar != null) await repo.removeImageByUrl('avatars', initial.avatarUrl);
      if (_banner != null) await repo.removeImageByUrl('banners', initial.bannerUrl);

      ref.invalidate(profileByUsernameProvider);
      if (!mounted) return;
      context.pop();
      auth.reloadProfile();
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
    final t = Theme.of(context);
    return Form(
      key: _key,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _BannerPicker(
            current: widget.initial.bannerUrl,
            picked: _banner,
            onTap: () async {
              final img = await _pick(maxWidth: 1600);
              if (img != null) setState(() => _banner = img);
            },
          ),
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: () async {
                final img = await _pick(maxWidth: 512);
                if (img != null) setState(() => _avatar = img);
              },
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  _avatar != null
                      ? CircleAvatar(radius: 44, backgroundImage: MemoryImage(_avatar!.bytes))
                      : UserAvatar(url: widget.initial.avatarUrl, radius: 44),
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: t.colorScheme.primary,
                    child: const Icon(Icons.camera_alt, size: 16, color: Colors.black),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _display,
            maxLength: 40,
            decoration: const InputDecoration(labelText: 'Display name'),
          ),
          TextFormField(
            controller: _username,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Username', prefixText: '@'),
            validator: Validators.username,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _bio,
            maxLines: 4,
            maxLength: 300,
            decoration: const InputDecoration(labelText: 'Bio'),
            validator: Validators.bio,
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _mc,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Minecraft username'),
            validator: Validators.minecraftUsername,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String?>(
            value: _edition,
            decoration: const InputDecoration(labelText: 'Minecraft edition'),
            items: const [
              DropdownMenuItem(value: null, child: Text('Not set')),
              DropdownMenuItem(value: 'java', child: Text('Java Edition')),
              DropdownMenuItem(value: 'bedrock', child: Text('Bedrock Edition')),
            ],
            onChanged: (v) => setState(() => _edition = v),
          ),
          const SizedBox(height: 24),
          Text('Links', style: t.textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final (ctrl, label, icon) in [
            (_youtube, 'YouTube', Icons.smart_display),
            (_tiktok, 'TikTok', Icons.music_note),
            (_website, 'Website', Icons.link),
          ]) ...[
            TextFormField(
              controller: ctrl,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
              validator: Validators.optionalUrl,
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _discord,
            autocorrect: false,
            decoration: const InputDecoration(
                labelText: 'Discord username', prefixIcon: Icon(Icons.forum)),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('Save changes'),
          ),
        ],
      ),
    );
  }
}

class _BannerPicker extends StatelessWidget {
  const _BannerPicker({required this.current, required this.picked, required this.onTap});
  final String? current;
  final PickedImage? picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (picked != null)
                Image.memory(picked!.bytes, fit: BoxFit.cover)
              else if (current != null)
                Image.network(current!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => ColoredBox(color: scheme.surfaceContainerHighest))
              else
                ColoredBox(color: scheme.surfaceContainerHighest),
              const Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircleAvatar(
                      radius: 14, child: Icon(Icons.camera_alt, size: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
