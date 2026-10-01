import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_failure.dart';

class PagedState<T> {
  const PagedState({
    this.items = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<T> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  PagedState<T> copyWith({
    List<T>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) =>
      PagedState<T>(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Cursor-based pagination: subclasses fetch the page that follows [last]
/// (or the first page when [last] is null).
abstract class PagedNotifier<T> extends StateNotifier<PagedState<T>> {
  PagedNotifier() : super(PagedState<T>()) {
    Future.microtask(refresh);
  }

  int get pageSize => 20;

  Future<List<T>> fetchPage(T? last);

  Future<void> refresh() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: state.items.isEmpty, clearError: true);
    try {
      final page = await fetchPage(null);
      if (!mounted) return;
      state = PagedState<T>(items: page, isLoading: false, hasMore: page.length >= pageSize);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: AppFailure.from(e).message);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore || state.items.isEmpty) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final page = await fetchPage(state.items.last);
      if (!mounted) return;
      state = state.copyWith(
        items: [...state.items, ...page],
        isLoadingMore: false,
        hasMore: page.length >= pageSize,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoadingMore: false, error: AppFailure.from(e).message);
    }
  }

  void mutate(List<T> Function(List<T>) fn) {
    if (!mounted) return;
    state = state.copyWith(items: fn(state.items));
  }
}
