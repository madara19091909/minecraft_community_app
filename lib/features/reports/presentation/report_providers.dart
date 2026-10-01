import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/paged.dart';
import '../data/report_repository.dart';
import '../domain/report.dart';

final reportRepositoryProvider = Provider<ReportRepository>((_) => ReportRepository());

class ReportsController extends PagedNotifier<Report> {
  ReportsController(this._repo, this._status);
  final ReportRepository _repo;
  final String _status;

  @override
  Future<List<Report>> fetchPage(Report? last) =>
      _repo.fetchQueue(status: _status, before: last?.createdAt, limit: pageSize);
}

final reportsProvider =
    StateNotifierProvider.autoDispose.family<ReportsController, PagedState<Report>, String>(
  (ref, status) => ReportsController(ref.watch(reportRepositoryProvider), status),
);

final reportProvider = FutureProvider.autoDispose.family<Report?, String>(
  (ref, id) => ref.watch(reportRepositoryProvider).fetchById(id),
);
