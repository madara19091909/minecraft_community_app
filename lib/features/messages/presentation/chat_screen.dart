import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/picked_image.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../home/presentation/image_viewer.dart';
import '../../reports/presentation/report_sheet.dart';
import '../domain/chat_info.dart';
import '../domain/message.dart';
import 'message_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scroll = ScrollController();
  final _input = TextEditingController();
  bool _sending = false;
  Message? _replyTo;
  Message? _editing;
  PickedImage? _image;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      // The list is reversed: maxScrollExtent is the oldest loaded message.
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        ref.read(chatControllerProvider(widget.conversationId).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _input.text.trim();
    final ctrl = ref.read(chatControllerProvider(widget.conversationId).notifier);
    setState(() => _sending = true);
    try {
      final editing = _editing;
      if (editing != null) {
        if (text.isEmpty) return;
        await ctrl.edit(editing, text);
        if (mounted) setState(() => _editing = null);
      } else {
        if (text.isEmpty && _image == null) return;
        await ctrl.send(content: text, image: _image, replyTo: _replyTo?.id);
        if (mounted) {
          setState(() {
            _replyTo = null;
            _image = null;
          });
        }
      }
      _input.clear();
      if (_scroll.hasClients) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickImage() async {
    final img = await pickSingleImage(maxWidth: 1600);
    if (img != null && mounted) setState(() => _image = img);
  }

  void _showActions(Message m, bool mine) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.reply),
            title: const Text('Reply'),
            onTap: () {
              Navigator.pop(ctx);
              setState(() {
                _replyTo = m;
                _editing = null;
              });
            },
          ),
          if (m.content.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: m.content));
                Navigator.pop(ctx);
              },
            ),
          if (!mine)
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report'),
              onTap: () {
                Navigator.pop(ctx);
                showReportSheet(context, targetType: 'message', targetId: m.id);
              },
            ),
          if (mine && !m.hasMedia)
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _editing = m;
                  _replyTo = null;
                  _image = null;
                  _input.text = m.content;
                });
              },
            ),
          if (mine)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await confirmDialog(context,
                    title: 'Delete message?',
                    message: 'It will be removed for everyone.',
                    confirmLabel: 'Delete');
                if (!ok) return;
                try {
                  await ref
                      .read(chatControllerProvider(widget.conversationId).notifier)
                      .delete(m);
                } catch (e) {
                  if (mounted) showErrorSnack(context, e);
                }
              },
            ),
        ]),
      ),
    );
  }

  Future<void> _leaveGroup() async {
    final ok = await confirmDialog(context,
        title: 'Leave group?',
        message: 'You will stop receiving messages from this group.',
        confirmLabel: 'Leave');
    if (!ok) return;
    try {
      await ref.read(messageRepositoryProvider).leaveGroup(widget.conversationId);
      ref.read(inboxProvider.notifier).refresh();
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.conversationId;
    final myId = ref.watch(authControllerProvider.select((a) => a.profile?.id));
    final chat = ref.watch(chatControllerProvider(id));
    final infoAsync = ref.watch(chatInfoProvider(id));
    final info = infoAsync.valueOrNull;
    final other = info?.other(myId);

    Widget body;
    if (chat.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (chat.error != null && chat.items.isEmpty) {
      body = ErrorView(
        message: chat.error!,
        onRetry: ref.read(chatControllerProvider(id).notifier).refresh,
      );
    } else if (chat.items.isEmpty) {
      body = const EmptyView(
        icon: Icons.waving_hand_outlined,
        title: 'Say hi 👋',
        subtitle: 'Messages are delivered in real time.',
      );
    } else {
      final msgs = chat.items;
      final lastMineIdx = msgs.indexWhere((m) => m.senderId == myId && !m.isDeleted);
      body = ListView.builder(
        controller: _scroll,
        reverse: true,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        itemCount: msgs.length + 1,
        itemBuilder: (context, i) {
          if (i == msgs.length) {
            if (chat.isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            return const SizedBox(height: 4);
          }
          final m = msgs[i];
          final mine = m.senderId == myId;
          String? seen;
          if (i == lastMineIdx && info != null) {
            final n = info.readersOf(m.createdAt, myId);
            if (n > 0) seen = info.isGroup ? 'Seen by $n' : 'Seen';
          }
          final replied = m.replyTo == null
              ? null
              : msgs.cast<Message?>().firstWhere((x) => x!.id == m.replyTo, orElse: () => null);
          return _Bubble(
            message: m,
            mine: mine,
            senderName: (info?.isGroup ?? false) && !mine ? info!.members[m.senderId]?.displayName ?? 'Member' : null,
            replied: replied,
            repliedName: replied == null ? null : _nameOf(info, replied.senderId, myId),
            hasReply: m.replyTo != null,
            seenLabel: seen,
            onLongPress: m.isDeleted ? null : () => _showActions(m, mine),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: GestureDetector(
          onTap: (!(info?.isGroup ?? true) && other != null)
              ? () => context.push(Routes.user(other.username))
              : null,
          child: Row(children: [
            if (info != null && !info.isGroup)
              UserAvatar(url: other?.avatarUrl, radius: 18)
            else
              CircleAvatar(
                radius: 18,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.groups, size: 20),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(info?.titleFor(myId) ?? 'Chat',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                if (info?.isGroup ?? false)
                  Text('${info!.members.length} members',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
              ]),
            ),
          ]),
        ),
        actions: [
          if (info?.isGroup ?? false)
            PopupMenuButton<String>(
              onSelected: (_) => _leaveGroup(),
              itemBuilder: (_) => const [PopupMenuItem(value: 'leave', child: Text('Leave group'))],
            ),
        ],
      ),
      body: Column(children: [
        if (infoAsync.hasError && info == null)
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.errorContainer,
            padding: const EdgeInsets.all(8),
            child: Text(AppFailure.from(infoAsync.error!).message, textAlign: TextAlign.center),
          ),
        Expanded(child: body),
        _InputBar(
          controller: _input,
          sending: _sending,
          replyTo: _replyTo,
          replyName: _replyTo == null ? null : _nameOf(info, _replyTo!.senderId, myId),
          editing: _editing != null,
          image: _image,
          onCancelContext: () => setState(() {
            _replyTo = null;
            if (_editing != null) _input.clear();
            _editing = null;
          }),
          onRemoveImage: () => setState(() => _image = null),
          onPickImage: _pickImage,
          onSend: _send,
        ),
      ]),
    );
  }

  String _nameOf(ChatInfo? info, String userId, String? myId) =>
      userId == myId ? 'You' : (info?.members[userId]?.displayName ?? 'Member');
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.hasReply,
    this.senderName,
    this.replied,
    this.repliedName,
    this.seenLabel,
    this.onLongPress,
  });

  final Message message;
  final bool mine;
  final String? senderName;
  final bool hasReply;
  final Message? replied;
  final String? repliedName;
  final String? seenLabel;
  final VoidCallback? onLongPress;

  static String _hhmm(DateTime t) {
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final m = message;
    final bg = mine
        ? t.colorScheme.primary.withValues(alpha: 0.22)
        : t.colorScheme.surfaceContainerHighest;

    String? replyText() {
      if (!hasReply) return null;
      if (replied == null) return 'Original message';
      if (replied!.isDeleted) return 'Message deleted';
      if (replied!.content.isNotEmpty) return replied!.content;
      return replied!.hasMedia ? 'Photo' : '';
    }

    final rt = replyText();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (senderName != null)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 2),
              child: Text(senderName!,
                  style: TextStyle(fontSize: 12, color: t.colorScheme.primary, fontWeight: FontWeight.w700)),
            ),
          GestureDetector(
            onLongPress: onLongPress,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(mine ? 16 : 4),
                    bottomRight: Radius.circular(mine ? 4 : 16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (rt != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          border: Border(left: BorderSide(color: t.colorScheme.primary, width: 3)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (repliedName != null)
                            Text(repliedName!,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: t.colorScheme.primary)),
                          Text(rt,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: t.hintColor)),
                        ]),
                      ),
                    if (m.isDeleted)
                      Text('Message deleted',
                          style: TextStyle(fontStyle: FontStyle.italic, color: t.hintColor))
                    else ...[
                      if (m.mediaPath != null) _ChatImage(path: m.mediaPath!),
                      if (m.content.isNotEmpty) ...[
                        if (m.mediaPath != null) const SizedBox(height: 6),
                        Text(m.content, style: const TextStyle(height: 1.3)),
                      ],
                    ],
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        '${m.isEdited && !m.isDeleted ? 'edited · ' : ''}${_hhmm(m.createdAt)}',
                        style: TextStyle(fontSize: 11, color: t.hintColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (seenLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 4),
              child: Text(seenLabel!, style: TextStyle(fontSize: 11, color: t.hintColor)),
            ),
        ],
      ),
    );
  }
}

class _ChatImage extends ConsumerWidget {
  const _ChatImage({required this.path});
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(chatImageUrlProvider(path));
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 220,
        height: 220,
        child: url.when(
          loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (_, __) => const Center(child: Icon(Icons.broken_image)),
          data: (u) => GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ImageViewerScreen(urls: [u]),
            )),
            child: CachedNetworkImage(
              imageUrl: u,
              cacheKey: path, // signed URLs change; the file does not
              fit: BoxFit.cover,
              memCacheWidth: 660,
              errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
            ),
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.sending,
    required this.replyTo,
    required this.replyName,
    required this.editing,
    required this.image,
    required this.onCancelContext,
    required this.onRemoveImage,
    required this.onPickImage,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final Message? replyTo;
  final String? replyName;
  final bool editing;
  final PickedImage? image;
  final VoidCallback onCancelContext;
  final VoidCallback onRemoveImage;
  final VoidCallback onPickImage;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final banner = editing
        ? 'Editing message'
        : replyTo != null
            ? 'Replying to $replyName'
            : null;

    return Material(
      color: t.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (banner != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
              child: Row(children: [
                Icon(editing ? Icons.edit : Icons.reply, size: 16, color: t.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    replyTo != null && !editing
                        ? '$banner: ${replyTo!.content.isEmpty ? 'Photo' : replyTo!.content}'
                        : banner,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: t.hintColor, fontSize: 13),
                  ),
                ),
                IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onCancelContext),
              ]),
            ),
          if (image != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(image!.bytes, height: 84, width: 84, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: onRemoveImage,
                      child: const CircleAvatar(
                        radius: 11,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 6, 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (!editing)
                IconButton(
                  tooltip: 'Photo',
                  onPressed: sending ? null : onPickImage,
                  icon: const Icon(Icons.image_outlined),
                ),
              if (editing) const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 4000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Message', counterText: ''),
                ),
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                onPressed: sending ? null : onSend,
                icon: sending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : Icon(editing ? Icons.check : Icons.send, color: Colors.black),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
