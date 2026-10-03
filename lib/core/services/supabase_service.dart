import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

class SupabaseService {
  const SupabaseService._();

  static Future<void> initialize() => Supabase.initialize(
        url: Env.supabaseUrl,
        anonKey: Env.supabaseAnonKey,
      );

  static SupabaseClient get client => Supabase.instance.client;
}
