import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/time_ago.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/presentation/permission_provider.dart';
import '../../home/presentation/post_providers.dart';
import '../domain/report.dart';
import 'report_providers.dart';

class ReportDetailScreen extends ConsumerStatefulWidget {
  const ReportDetailScreen({super.key, required this.reportId});
  final String reportId;

  @override
  ConsumerState<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends ConsumerState<ReportDetailScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(reportProvider(widget.reportId));
      ref.invalidate(reportsProvider);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askNote(String title) async {
    final ctrl = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(hintText: 'Note (optional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Confirm')),
        ],
      ),
    );
    ctrl.dispose();
    return res; // null = cancelled, '' = confirmed without note
  }

  Future<void> _setStatus(Report r, String status) async {
    String? note;
    if (status != 'reviewing') {
      note = await _askNote(status == 'resolved' ? 'Resolve report' : 'Reject report');
      if (note == null) return;
    }
    await _run(() => ref.read(reportRepositoryProvider).review(r.id, status, note: note));
  }

  Future<void> _removeContent(Report r) async {
    final ok = await confirmDialog(context,
        title: 'Remove ${r.typeLabel.toLowerCase()}?',
        message: 'The content is deleted for everyone and the report is marked resolved.',
        confirmLabel: 'Remove');
    if (!ok) return;
    await _run(() async {
      if (r.targetType == 'post') {
        await ref.read(postRepositoryProvider).deletePost(r.targetId);
      } else {
        await ref.read(postRepositoryProvider).deleteComment(r.targetId);
      }
      await ref.read(reportRepositoryProvider).review(r.id, 'resolved', note: 'Content removed');
    });
  }

  Future<void> _suspend(Report r) async {
    final ok = await confirmDialog(context,
        title: 'Suspend @${r.ownerUsername ?? 'user'}?',
        message: 'They will lose access to the app until an admin reactivates them.',
        confirmLabel: 'Suspend');
    if (!ok) return;
    await _run(() async {
      await ref.read(reportRepositoryProvider).suspendUser(r.targetOwnerId!);
      await ref.read(reportRepositoryProvider).review(r.id, 'resolved', note: 'User suspended');
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(reportProvider(widget.reportId));
    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: async.when(
        skipLoadingOnReload: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: AppFailure.from(e).message,
          onRetry: () => ref.invalidate(reportProvider(widget.reportId)),
        ),
        data: (r) => r == null
            ? const EmptyView(icon: Icons.search_off, title: 'Report not found')
            : _content(r),
      ),
    );
  }

  Widget _content(Report r) {
    final t = Theme.of(context);
    final canSuspend = ref.watch(permissionProvider('users.manage')).valueOrNull ?? false;

    Widget row(String label, String? value) => value == null || value.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label.toUpperCase(),
                  style: TextStyle(fontSize: 11, letterSpacing: 0.6, color: t.hintColor, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(value),
            ]),
          );

    VoidCallback? openTarget;
    if (r.targetType == 'post') openTarget = () => context.push(Routes.post(r.targetId));
    if (r.targetType == 'community') openTarget = () => context.push(Routes.community(r.targetId));
    if (r.targetType == 'user' && r.ownerUsername != null) {
      openTarget = () => context.push(Routes.user(r.ownerUsername!));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Chip(label: Text(r.status.toUpperCase())),
          const SizedBox(width: 8),
          Text(timeAgo(r.createdAt), style: TextStyle(color: t.hintColor)),
        ]),
        const SizedBox(height: 12),
        row('Target', r.typeLabel),
        row('Reason', r.reasonLabel),
        row('Details from reporter', r.description),
        row('Content at time of report', r.snapshot),
        row('Reported user', r.ownerUsername == null ? null : '@${r.ownerUsername}'),
        row('Reported by', r.reporterUsername == null ? null : '@${r.reporterUsername}'),
        if (!r.isOpen) ...[
          row('Reviewed by', r.reviewerUsername == null ? null : '@${r.reviewerUsername}'),
          row('Resolution note', r.resolutionNote),
        ],
        if (openTarget != null)
          OutlinedButton.icon(
            onPressed: openTarget,
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text('Open ${r.typeLabel.toLowerCase()}'),
          ),
        if (_busy)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else if (r.isOpen) ...[
          const SizedBox(height: 20),
          Text('Actions', style: t.textTheme.titleMedium),
          const SizedBox(height: 10),
          if (r.targetType == 'post' || r.targetType == 'comment')
            OutlinedButton.icon(
              onPressed: () => _removeContent(r),
              icon: const Icon(Icons.delete_outline),
              label: Text('Remove ${r.typeLabel.toLowerCase()}'),
            ),
          if (canSuspend && r.targetOwnerId != null && r.targetType != 'community') ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _suspend(r),
              icon: const Icon(Icons.pause_circle_outline),
              label: const Text('Suspend user'),
            ),
          ],
          const SizedBox(height: 16),
          Row(children: [
            if (r.status == 'pending')
              Expanded(
                child: OutlinedButton(
                    onPressed: () => _setStatus(r, 'reviewing'), child: const Text('Reviewing')),
              ),
            if (r.status == 'pending') const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                  onPressed: () => _setStatus(r, 'rejected'), child: const Text('Reject')),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () => _setStatus(r, 'resolved'),
                child: const Text('Resolve'),
              ),
            ),
          ]),
        ],
      ],
    );
  }
}
