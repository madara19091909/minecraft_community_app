import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/message_repository.dart';
import 'message_providers.dart';

class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final _title = TextEditingController();
  final _selected = <String, UserSummary>{};
  Timer? _debounce;
  String _query = '';
  bool _group = false;
  bool _busy = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  Future<void> _openDirect(UserSummary u) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final id = await ref.read(messageRepositoryProvider).startDirect(u.id);
      ref.read(inboxProvider.notifier).refresh();
      if (mounted) context.pushReplacement(Routes.chat(id));
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createGroup() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final id = await ref
          .read(messageRepositoryProvider)
          .createGroup(_title.text, _selected.keys.toList());
      ref.read(inboxProvider.notifier).refresh();
      if (mounted) context.pushReplacement(Routes.chat(id));
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final results = ref.watch(userSearchProvider(_query));
    final canCreate = _title.text.trim().isNotEmpty && _selected.isNotEmpty && !_busy;

    return Scaffold(
      appBar: AppBar(
        title: Text(_group ? 'New group' : 'New chat'),
        actions: [
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                      _group = !_group;
                      _selected.clear();
                    }),
            child: Text(_group ? 'Cancel' : 'New group'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_group)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _title,
                maxLength: 60,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Group name',
                  prefixIcon: Icon(Icons.groups_outlined),
                  counterText: '',
                ),
              ),
            ),
          if (_group && _selected.isNotEmpty)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final u in _selected.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: InputChip(
                        avatar: UserAvatar(url: u.avatarUrl, radius: 12),
                        label: Text(u.displayName),
                        onDeleted: () => setState(() => _selected.remove(u.id)),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: TextField(
              autofocus: !_group,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                hintText: 'Search people by name or @username',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: results.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(AppFailure.from(e).message)),
              data: (users) {
                if (_query.length < 2) {
                  return const EmptyView(
                    icon: Icons.person_search,
                    title: 'Find people',
                    subtitle: 'Type at least 2 characters.',
                  );
                }
                if (users.isEmpty) {
                  return EmptyView(icon: Icons.search_off, title: 'No results for "$_query"');
                }
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (_, i) {
                    final u = users[i];
                    final picked = _selected.containsKey(u.id);
                    return ListTile(
                      leading: UserAvatar(url: u.avatarUrl, radius: 22),
                      title: Text(u.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('@${u.username}'),
                      trailing: _group ? Checkbox(value: picked, onChanged: (_) => _toggle(u)) : null,
                      onTap: _group ? () => _toggle(u) : () => _openDirect(u),
                    );
                  },
                );
              },
            ),
          ),
          if (_group)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: canCreate ? _createGroup : null,
                  child: _busy
                      ? const SizedBox(
                          height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : Text('Create group (${_selected.length})',
                          style: TextStyle(color: canCreate ? null : t.hintColor)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _toggle(UserSummary u) => setState(() {
        if (_selected.remove(u.id) == null) {
          if (_selected.length < 49) _selected[u.id] = u;
        }
      });
}
