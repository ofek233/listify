import 'package:flutter/foundation.dart';
import '../models/search_result_model.dart';
import '../models/search_filter_model.dart';
import '../models/recent_search.dart';
import '../services/search_service.dart';

/// Manages search UI state using ValueNotifiers
/// Provides reactive state for search results, filters, and recent searches
class SearchStateProvider {
  final SearchService _searchService;

  late ValueNotifier<SearchResultModel?> searchResults;
  late ValueNotifier<SearchFilterModel> filterState;
  late ValueNotifier<List<RecentSearch>> recentSearches;
  late ValueNotifier<bool> isSearching;
  late ValueNotifier<bool> showRecentSearches;

  SearchStateProvider({required SearchService searchService})
      : _searchService = searchService {
    // Initialize notifiers
    searchResults = ValueNotifier<SearchResultModel?>(null);
    filterState = ValueNotifier<SearchFilterModel>(const SearchFilterModel());
    recentSearches = ValueNotifier<List<RecentSearch>>([]);
    isSearching = ValueNotifier<bool>(false);
    showRecentSearches = ValueNotifier<bool>(false);
  }

  /// Initialize state (load recent searches)
  Future<void> initialize() async {
    await _loadRecentSearches();
  }

  /// Perform a search with the given query
  Future<void> search(String query) async {
    isSearching.value = true;
    showRecentSearches.value = false;

    try {
      final results = await _searchService.performSearch(
        query: query,
        filters: filterState.value,
        addToHistory: true,
      );

      searchResults.value = results;

      // Reload recent searches after adding new one
      await _loadRecentSearches();
    } catch (e) {
      print('Error during search: $e');
      searchResults.value = SearchResultModel.empty(query);
    } finally {
      isSearching.value = false;
    }
  }

  /// Clear current search results
  void clearSearch() {
    searchResults.value = null;
    showRecentSearches.value = false;
  }

  /// Show recent searches (when search bar is focused but empty)
  Future<void> showRecentSearchesView() async {
    showRecentSearches.value = true;
    await _loadRecentSearches();
  }

  /// Hide recent searches view
  void hideRecentSearchesView() {
    showRecentSearches.value = false;
  }

  /// Re-run a recent search from history
  Future<void> runRecentSearch(String query) async {
    await search(query);
  }

  /// Update filter state and re-run search if results exist
  Future<void> updateFilters(SearchFilterModel newFilters) async {
    filterState.value = newFilters;

    // Re-run search if there are current results
    if (searchResults.value != null && searchResults.value!.searchQuery.isNotEmpty) {
      await search(searchResults.value!.searchQuery);
    }
  }

  /// Reset filters to defaults
  Future<void> resetFilters() async {
    filterState.value = const SearchFilterModel();

    // Re-run search if there are current results
    if (searchResults.value != null && searchResults.value!.searchQuery.isNotEmpty) {
      await search(searchResults.value!.searchQuery);
    }
  }

  /// Clear search history
  Future<void> clearHistory() async {
    await _searchService.clearSearchHistory();
    await _loadRecentSearches();
  }

  /// Remove specific search from history
  Future<void> removeFromHistory(String query) async {
    await _searchService.removeSearchFromHistory(query);
    await _loadRecentSearches();
  }

  /// Load recent searches from repository
  Future<void> _loadRecentSearches() async {
    try {
      final recent = await _searchService.getRecentSearches();
      recentSearches.value = recent;
    } catch (e) {
      print('Error loading recent searches: $e');
      recentSearches.value = [];
    }
  }

  /// Dispose all notifiers
  void dispose() {
    searchResults.dispose();
    filterState.dispose();
    recentSearches.dispose();
    isSearching.dispose();
    showRecentSearches.dispose();
  }

  /// Get current search query for display
  String get currentSearchQuery =>
      searchResults.value?.searchQuery ?? '';

  /// Get count of result lists
  int get resultListCount =>
      searchResults.value?.listCount ?? 0;

  /// Get count of result items
  int get resultItemCount =>
      searchResults.value?.totalItems ?? 0;

  /// Check if there are active filters
  bool get hasActiveFilters =>
      filterState.value.isActive;

  /// Get filter summary text
  String get filterSummary {
    final descriptions = filterState.value.getActiveFilterDescriptions();
    return descriptions.isEmpty ? 'No filters' : descriptions.join(' • ');
  }
}
