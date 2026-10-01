import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/services/supabase_service.dart';
import 'core/widgets/error_view.dart';
import 'features/settings/presentation/settings_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Env.isConfigured) {
    runApp(const MaterialApp(
      home: Scaffold(
        body: ErrorView(
          message:
              'Missing SUPABASE_URL / SUPABASE_ANON_KEY.\nRun with --dart-define-from-file=env.json',
        ),
      ),
    ));
    return;
  }
  await SupabaseService.initialize();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const BlockverseApp(),
  ));
}
