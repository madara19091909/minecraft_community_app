import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/env.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/ui_helpers.dart';
import 'settings_widgets.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showErrorSnack(context, const AppFailure('Could not open the link.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(children: [
        SettingsSection(title: 'App', children: [
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (_, snap) => ListTile(
              leading: const Icon(Icons.tag),
              title: const Text('Version'),
              subtitle: Text(snap.hasData ? '${snap.data!.version} (${snap.data!.buildNumber})' : '…'),
            ),
          ),
        ]),
        SettingsSection(title: 'Legal', children: [
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            subtitle: Env.termsUrl.isEmpty ? const Text('Not published yet') : null,
            enabled: Env.termsUrl.isNotEmpty,
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _open(context, Env.termsUrl),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            subtitle: Env.privacyUrl.isEmpty ? const Text('Not published yet') : null,
            enabled: Env.privacyUrl.isNotEmpty,
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _open(context, Env.privacyUrl),
          ),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('Open-source licenses'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(context: context, applicationName: 'Blockverse'),
          ),
        ]),
        SettingsSection(title: 'Credits', children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Built with Flutter and Supabase.\n\n'
              'Blockverse is a community project. It is not an official Minecraft product '
              'and is not approved by or associated with Mojang or Microsoft.',
              style: TextStyle(color: t.hintColor, height: 1.4),
            ),
          ),
        ]),
      ]),
    );
  }
}
