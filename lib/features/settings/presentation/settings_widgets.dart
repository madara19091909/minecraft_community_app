import 'package:flutter/material.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
          child: Text(title.toUpperCase(),
              style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w800,
                  color: t.hintColor)),
        ),
        ...children,
      ],
    );
  }
}

/// A row showing the current value; tapping opens a radio sheet.
class ChoiceTile<T> extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return ListTile(
      title: Text(title),
      subtitle: Text(
        [options[value] ?? '', if (subtitle != null) subtitle!].where((s) => s.isNotEmpty).join(' · '),
        style: TextStyle(color: t.hintColor),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
            ),
            RadioGroup<T>(
              groupValue: value,
              onChanged: (v) {
                Navigator.pop(ctx);
                if (v != null && v != value) onChanged(v);
              },
              child: Column(children: [
                for (final e in options.entries)
                  RadioListTile<T>(value: e.key, title: Text(e.value)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
