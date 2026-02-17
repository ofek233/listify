import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../database_helper.dart';
import '../models/search_query.dart';
import '../models/search_result_model.dart';
import '../models/search_filter_model.dart';
import '../models/recent_search.dart';
import '../models/list_item_model.dart';
import 'firestore_service.dart';
import 'recent_searches_repository.dart';

/// Orchestrates search across both local (SQLite) and cloud (Firestore) data sources
/// Provides unified search API and handles result aggregation
class SearchService {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final FirestoreService _firestoreService = FirestoreService();
  final RecentSearchesRepository _recentSearchesRepo = RecentSearchesRepository();

  late String _userId;
  bool _initialized = false;

  /// Initialize the search service with current user ID
  Future<void> init(String userId) async {
    _userId = userId;
    await _recentSearchesRepo.init();
    _initialized = true;
  }

  /// Ensure initialization
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await init(user.uid);
      }
    }
  }

  /// Perform a unified search across all data sources
  /// 
  /// Parameters:
  /// - query: Unparsed search input (may contain filters like "text completed:yes")
  /// - filters: Additional filter state from the UI
  /// - addToHistory: Whether to save this search to recent searches history
  ///
  /// Returns: SearchResultModel with grouped results
  Future<SearchResultModel> performSearch({
    required String query,
    required SearchFilterModel filters,
    bool addToHistory = true,
  }) async {
    await _ensureInitialized();

    if (query.isEmpty) {
      return SearchResultModel.empty('');
    }

    try {
      // Parse the query to extract filters
      final parsedQuery = SearchQuery.parse(query);

      // Merge parsed filters with UI filters
      final mergedQuery = _mergeFilters(parsedQuery, filters);

        // Perform local search (SQLite) or cloud search (Firestore on web)
        final results = kIsWeb
          ? await _searchCloud(mergedQuery)
          : await _searchLocal(mergedQuery);

      // If there are results and user added to history, save it
      if (addToHistory) {
        final totalCount = results.totalItems;
        final recentSearch = RecentSearch(
          query: query,
          timestamp: DateTime.now(),
          resultCount: totalCount,
        );
        await _recentSearchesRepo.addSearch(recentSearch);
      }

      return results;
    } catch (e) {
      print('Error during search: $e');
      return SearchResultModel.empty(query);
    }
  }

  /// Search local SQLite database
  Future<SearchResultModel> _searchLocal(SearchQuery query) async {
    if (kIsWeb) {
      return SearchResultModel.empty(query.baseQuery);
    }
    try {
      // Get all folders for context mapping
      final folders = await _databaseHelper.getFolders();
      final folderMap = {for (var f in folders) f.id: f.name};

      // Perform the main search
      final results = await _databaseHelper.searchListsAndItemsGrouped(
        query: query.baseQuery,
        completionFilter: query.completionFilter,
        dateRangeStart: query.dateRangeStart,
        dateRangeEnd: query.dateRangeEnd,
        listTypes: query.listTypes,
        folderIdFilterMap: folderMap,
      );

      return results;
    } catch (e) {
      print('Error searching locally: $e');
      return SearchResultModel.empty(query.baseQuery);
    }
  }

  /// Search cloud (Firestore) data
  /// Currently limited due to Firestore cross-user query constraints
  Future<SearchResultModel> _searchCloud(SearchQuery query) async {
    try {
      final normalizedQuery = query.baseQuery.trim().toLowerCase();
      if (normalizedQuery.isEmpty) {
        return SearchResultModel.empty(query.baseQuery);
      }

      final folders = await _firestoreService.getUserFolders(_userId);
      final folderMap = {for (var f in folders) f.id: f.name};

      final lists = await _firestoreService.getUserLists(_userId);
      final groupedResults = <String, GroupedListResult>{};

      for (final list in lists) {
        final listTypeStr = list.type.toString().split('.').last;
        if (query.listTypes.isNotEmpty && !query.listTypes.contains(listTypeStr)) {
          continue;
        }

        final listMatches = list.title.toLowerCase().contains(normalizedQuery);

        // Fetch items for list and filter locally
        final itemDocs = await _firestoreService.getListItems(list.id, _userId);
        final matchingItems = <ListItemModel>[];

        for (final itemData in itemDocs) {
          final title = (itemData['title'] as String? ?? '').trim();
          final completed = itemData['completed'] == true;
          final matchesText = title.toLowerCase().contains(normalizedQuery);

          if (!matchesText && !listMatches) {
            continue;
          }

          if (query.completionFilter == CompletionStatus.completed && !completed) {
            continue;
          }
          if (query.completionFilter == CompletionStatus.pending && completed) {
            continue;
          }

          matchingItems.add(
            ListItemModel(
              id: itemData['id']?.toString() ?? '',
              title: title,
              listId: list.id,
              completed: completed,
              order: 0,
            ),
          );
        }

        if (listMatches || matchingItems.isNotEmpty) {
          groupedResults[list.id] = GroupedListResult(
            list: list,
            parentFolderName: folderMap[list.folderId],
            parentFolderId: list.folderId,
            matchingItems: matchingItems,
          );
        }
      }

      return SearchResultModel(
        groupedResults: groupedResults,
        searchQuery: query.baseQuery,
        totalResultCount: groupedResults.values
            .fold(0, (sum, group) => sum + group.itemCount),
      );
    } catch (e) {
      print('Error searching cloud: $e');
      return SearchResultModel.empty(query.baseQuery);
    }
  }

  /// Merge parsed query filters with UI filter selections
  /// UI filters take precedence over query syntax
  SearchQuery _mergeFilters(SearchQuery parsedQuery, SearchFilterModel uiFilters) {
    return SearchQuery(
      baseQuery: parsedQuery.baseQuery,
      completionFilter:
          uiFilters.completionStatus != CompletionStatus.all
              ? uiFilters.completionStatus
              : parsedQuery.completionFilter,
      dateRangeStart: uiFilters.dateRange?.start ?? parsedQuery.dateRangeStart,
      dateRangeEnd: uiFilters.dateRange?.end ?? parsedQuery.dateRangeEnd,
      listTypes: uiFilters.selectedListTypes.isNotEmpty
          ? uiFilters.selectedListTypes
          : parsedQuery.listTypes,
      collaboratorEmail: uiFilters.collaboratorEmail ?? parsedQuery.collaboratorEmail,
    );
  }

  /// Get recent searches from history
  Future<List<RecentSearch>> getRecentSearches() async {
    await _ensureInitialized();
    return await _recentSearchesRepo.getRecentSearches();
  }

  /// Clear search history
  Future<void> clearSearchHistory() async {
    await _ensureInitialized();
    await _recentSearchesRepo.clearHistory();
  }

  /// Remove a specific search from history
  Future<void> removeSearchFromHistory(String query) async {
    await _ensureInitialized();
    await _recentSearchesRepo.removeSearch(query);
  }

  /// Search for users by email for collaborator filtering
  Future<List<Map<String, dynamic>>> searchUsersByEmail(String email) async {
    await _ensureInitialized();
    return await _firestoreService.searchUsersByEmailPartial(email);
  }
}
