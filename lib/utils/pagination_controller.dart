import 'package:flutter/material.dart';

/// Reusable pagination + infinite-scroll controller.
/// Use one instance per list (products, search, etc.).
class PaginationController {
  PaginationController({this.loadMoreThreshold = 200});

  final double loadMoreThreshold;

  final ScrollController scrollController = ScrollController();

  bool isLoadingMore = false;
  bool hasMore = true;
  int currentPage = 1;
  int totalPages = 1;

  VoidCallback? _onLoadMore;

  /// Call in initState
  void init({required VoidCallback onLoadMore}) {
    _onLoadMore = onLoadMore;
    scrollController.addListener(_onScroll);
  }

  /// Call in dispose
  void dispose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
  }

  void _onScroll() {
    if (!scrollController.hasClients || isLoadingMore || !hasMore) return;

    final position = scrollController.position;
    if (position.pixels >= position.maxScrollExtent - loadMoreThreshold) {
      _onLoadMore?.call();
    }
  }

  /// Call after every successful page load
  void checkAndLoadMoreIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients || isLoadingMore || !hasMore) return;

      if (scrollController.position.maxScrollExtent <= 0) {
        _onLoadMore?.call();
      }
    });
  }

  void update({required int page, required int calculatedTotalPages}) {
    currentPage = page;
    totalPages = calculatedTotalPages;
    hasMore = currentPage < totalPages;
  }

  void reset() {
    currentPage = 1;
    totalPages = 1;
    hasMore = true;
    isLoadingMore = false;
  }
}
