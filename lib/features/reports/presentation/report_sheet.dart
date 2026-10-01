import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/ui_helpers.dart';
import '../domain/report.dart';
import 'report_providers.dart';

/// targetType: user | post | comment | message | community
Future<void> showReportSheet(
  BuildContext context, {
  required String targetType,
  required String targetId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _ReportForm(targetType: targetType, targetId: targetId),
    ),
  );
}

class _ReportForm extends ConsumerStatefulWidget {
  const _ReportForm({required this.targetType, required this.targetId});
  final String targetType;
  final String targetId;

  @override
  ConsumerState<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends ConsumerState<_ReportForm> {
  final _desc = TextEditingController();
  String? _reason;
  bool _busy = false;

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null || _busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await ref.read(reportRepositoryProvider).submit(
            targetType: widget.targetType,
            targetId: widget.targetId,
            reason: _reason!,
            description: _desc.text,
          );
      nav.pop();
      messenger.showSnackBar(const SnackBar(
          content: Text('Report sent. Thanks for helping keep the community safe.')));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showErrorSnack(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Report ${reportTypeLabels[widget.targetType]?.toLowerCase() ?? 'content'}',
                style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Why are you reporting this? Reports are reviewed by moderators.',
                style: TextStyle(color: t.hintColor)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in reportReasons.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _reason == e.key,
                    onSelected: _busy ? null : (_) => setState(() => _reason = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _desc,
              maxLines: 3,
              maxLength: 500,
              enabled: !_busy,
              decoration: const InputDecoration(hintText: 'Add details (optional)'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: (_reason == null || _busy) ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Send report'),
            ),
          ],
        ),
      ),
    );
  }
}
