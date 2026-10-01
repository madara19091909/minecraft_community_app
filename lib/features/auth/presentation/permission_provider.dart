import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_service.dart';
import 'auth_controller.dart';

/// Server-side permission check (UI uses it only to show/hide entry points;
/// the database enforces the real rule).
final permissionProvider = FutureProvider.family<bool, String>((ref, key) async {
  ref.watch(authControllerProvider.select((a) => a.profile?.id));
  try {
    final r = await SupabaseService.client.rpc('has_permission', params: {'p_key': key});
    return r == true;
  } catch (_) {
    return false;
  }
});
