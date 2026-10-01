import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_providers.dart';
import 'settings_widgets.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(appearanceProvider);
    final ctrl = ref.read(appearanceProvider.notifier);
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(children: [
        SettingsSection(title: 'Theme', children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto), label: Text('System')),
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Dark')),
              ],
              selected: {a.mode},
              onSelectionChanged: (s) => ctrl.setMode(s.first),
            ),
          ),
        ]),
        SettingsSection(title: 'Accent color', children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (var i = 0; i < accentOptions.length; i++)
                  Semantics(
                    label: accentOptions[i].name,
                    selected: a.accentIndex == i,
                    button: true,
                    child: GestureDetector(
                      onTap: () => ctrl.setAccent(i),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: accentOptions[i].color,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: a.accentIndex == i ? t.colorScheme.onSurface : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: a.accentIndex == i
                            ? const Icon(Icons.check, color: Colors.black)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(accentOptions[a.accentIndex].name, style: TextStyle(color: t.hintColor)),
          ),
        ]),
        SettingsSection(title: 'Themes', children: [
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: const Text('More themes'),
            subtitle: const Text('Profile themes and effects are planned'),
            enabled: false,
          ),
        ]),
      ]),
    );
  }
}
