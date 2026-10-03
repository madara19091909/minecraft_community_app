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

    // Keep emoji-only messages valid. We only reject text that contains no
    // visible characters at all and has no attached image.
    final raw = _input.text;
    final text = raw.trim();
    final hasText = text.runes.isNotEmpty;
    final hasImage = _image != null;

    final ctrl = ref.read(chatControllerProvider(widget.conversationId).notifier);
    setState(() => _sending = true);

    try {
      final editing = _editing;
      if (editing != null) {
        if (!hasText) return;
        await ctrl.edit(editing, text);
        if (mounted) setState(() => _editing = null);
      } else {
        if (!hasText && !hasImage) return;

        await ctrl.send(
          content: text,
          image: _image,
          replyTo: _replyTo?.id,
        );

        if (mounted) {
          setState(() {
            _replyTo = null;
            _image = null;
          });
        }
      }

      _input.clear();
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
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

class _InputBar extends StatefulWidget {
  const _InputBar({
    required this.controller, required this.sending, required this.replyTo,
    required this.replyName, required this.editing, required this.image,
    required this.onCancelContext, required this.onRemoveImage,
    required this.onPickImage, required this.onSend,
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

  @override State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _emojiOpen = false;

  static const _emojis = <String>[
    '😀','😃','😄','😁','😆','😅','😂','🤣','😊','😇','🙂','🙃','😉','😍','🥰','😘',
    '😋','😛','😝','😜','🤪','🤨','🤓','😎','🥳','😏','😒','😞','😔','😟','😕','🙁',
    '😣','😖','😫','😩','🥺','😢','😭','😤','😠','😡','🤬','🤯','😳','🥵','🥶','😱',
    '😨','😰','😥','😓','🤗','🤔','🫡','🤭','🤫','😶','😐','😑','😬','🙄','😮','😴',
    '🤤','😪','😵','🤐','🥴','🤢','🤮','🤧','😷','🤠','🤑','🤡','👻','💀','👽','🤖',
    '❤️','🧡','💛','💚','💙','💜','🖤','🤍','🤎','💔','🔥','✨','⭐','🌟','💫','💥',
    '💯','🎉','🎊','🏆','👑','💎','⚡','🎮','🕹️','⛏️','🧱','🗡️','🛡️','🏹','👍','👎',
    '👏','🙌','🤝','🙏','💪','👀','👋','✌️','❤️‍🔥','🤣','😭','💀','🗿','🐸','🐱','🐶',
  ];

  void _insertEmoji(String emoji) {
    final v = widget.controller.value;
    final s = v.selection.start < 0 ? v.text.length : v.selection.start;
    final e = v.selection.end < 0 ? v.text.length : v.selection.end;
    final next = v.text.replaceRange(s, e, emoji);
    widget.controller.value = v.copyWith(
      text: next,
      selection: TextSelection.collapsed(offset: s + emoji.length),
      composing: TextRange.empty,
    );
    setState(() {});
  }

  void _toggleEmoji() {
    FocusScope.of(context).unfocus();
    setState(() => _emojiOpen = !_emojiOpen);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final hasText = widget.controller.text.trim().runes.isNotEmpty;
    final canSend = !widget.sending && (hasText || widget.image != null);
    final banner = widget.editing
        ? 'Editing message'
        : widget.replyTo != null ? 'Replying to ${widget.replyName ?? 'message'}' : null;

    return Material(
      color: cs.surface,
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (banner != null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: .72),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                Icon(widget.editing ? Icons.edit_rounded : Icons.reply_rounded, size: 17, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  widget.replyTo != null && !widget.editing
                      ? '${widget.replyName ?? 'Message'}: ${widget.replyTo!.content.isEmpty ? 'Photo' : widget.replyTo!.content}'
                      : banner,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
                )),
                IconButton(visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: widget.onCancelContext),
              ]),
            ),
          if (widget.image != null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0), height: 78,
              alignment: Alignment.centerLeft,
              child: Stack(clipBehavior: Clip.none, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.memory(widget.image!.bytes, height: 78, width: 78, fit: BoxFit.cover),
                ),
                Positioned(right: -5, top: -5, child: GestureDetector(
                  onTap: widget.onRemoveImage,
                  child: Container(width: 23, height: 23,
                    decoration: BoxDecoration(color: cs.error, shape: BoxShape.circle,
                      border: Border.all(color: cs.surface, width: 2)),
                    child: Icon(Icons.close_rounded, size: 13, color: cs.onError)),
                )),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 52, maxHeight: 132),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(27),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: .35)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 16, offset: const Offset(0,5))],
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    if (!widget.editing)
                      IconButton(
                        tooltip: 'Emoji', onPressed: widget.sending ? null : _toggleEmoji,
                        icon: Icon(_emojiOpen ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
                          color: _emojiOpen ? cs.primary : cs.onSurfaceVariant),
                      ),
                    Expanded(child: TextField(
                      controller: widget.controller, minLines: 1, maxLines: 5, maxLength: 4000,
                      onTap: () { if (_emojiOpen) setState(() => _emojiOpen = false); },
                      onChanged: (_) => setState(() {}),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Write a message…', counterText: '', border: InputBorder.none,
                        enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 2),
                      ),
                    )),
                    if (!widget.editing)
                      IconButton(
                        tooltip: 'Photo', onPressed: widget.sending ? null : widget.onPickImage,
                        icon: Icon(Icons.attach_file_rounded, color: cs.onSurfaceVariant),
                      ),
                  ]),
                ),
              ),
              const SizedBox(width: 7),
              AnimatedScale(
                scale: canSend ? 1 : .92, duration: const Duration(milliseconds: 150),
                child: IconButton.filled(
                  tooltip: widget.editing ? 'Save' : 'Send',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(52,52), maximumSize: const Size(52,52),
                    shape: const CircleBorder(),
                    backgroundColor: canSend ? cs.primary : cs.surfaceContainerHighest,
                    foregroundColor: canSend ? cs.onPrimary : cs.onSurfaceVariant,
                  ),
                  onPressed: canSend ? widget.onSend : null,
                  icon: widget.sending
                      ? const SizedBox(width:19,height:19,child:CircularProgressIndicator(strokeWidth:2))
                      : Icon(widget.editing ? Icons.check_rounded : Icons.send_rounded, size:22),
                ),
              ),
            ]),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              height: 245, width: double.infinity,
              decoration: BoxDecoration(color: cs.surfaceContainerLow,
                border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha:.25)))),
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(12,10,12,12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8, mainAxisSpacing: 5, crossAxisSpacing: 5),
                itemCount: _emojis.length,
                itemBuilder: (context,index) => InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _insertEmoji(_emojis[index]),
                  child: Center(child: Text(_emojis[index], style: const TextStyle(fontSize:25))),
                ),
              ),
            ),
            crossFadeState: _emojiOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds:180),
          ),
        ]),
      ),
    );
  }
}
