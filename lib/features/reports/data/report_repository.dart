import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/report.dart';

class ReportRepository {
  ReportRepository([SupabaseClient? client]) : _client = client ?? SupabaseService.client;
  final SupabaseClient _client;

  Future<void> submit({
    required String targetType,
    required String targetId,
    required String reason,
    String? description,
  }) async {
    try {
      await _client.rpc('submit_report', params: {
        'p_type': targetType,
        'p_target': targetId,
        'p_reason': reason,
        'p_description': description,
      });
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<List<Report>> fetchQueue({required String status, DateTime? before, int limit = 20}) async {
    try {
      var q = _client.from('report_details').select().eq('status', status);
      if (before != null) q = q.lt('created_at', before.toUtc().toIso8601String());
      final rows = await q.order('created_at', ascending: false).limit(limit);
      return [for (final r in rows) Report.fromMap(r)];
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<Report?> fetchById(String id) async {
    try {
      final row = await _client.from('report_details').select().eq('id', id).maybeSingle();
      return row == null ? null : Report.fromMap(row);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> review(String id, String status, {String? note}) async {
    try {
      await _client.rpc('review_report', params: {'p_id': id, 'p_status': status, 'p_note': note});
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Requires users.manage (enforced by RLS + rank guard trigger).
  Future<void> suspendUser(String userId) async {
    try {
      final row = await _client
          .from('profiles')
          .update({'status': 'suspended'})
          .eq('id', userId)
          .select('id')
          .maybeSingle();
      if (row == null) throw const AppFailure("You can't suspend this user.");
    } on PostgrestException catch (e) {
      throw AppFailure(e.code == 'P0001' ? e.message : AppFailure.from(e).message);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }
}
