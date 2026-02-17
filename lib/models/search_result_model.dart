import 'list_model.dart';
import 'list_item_model.dart';

/// Represents a single grouping of items under a specific list
class GroupedListResult {
  final AppList list;
  final String? parentFolderName;
  final String? parentFolderId;
  final List<ListItemModel> matchingItems;

  GroupedListResult({
    required this.list,
    this.parentFolderName,
    this.parentFolderId,
    required this.matchingItems,
  });

  /// Returns a descriptive label for displaying the list context
  String getContextLabel() {
    if (parentFolderName != null && parentFolderName!.isNotEmpty) {
      return '$parentFolderName → ${list.title}';
    }
    return list.title;
  }

  /// Returns count of matching items for display
  int get itemCount => matchingItems.length;

  /// Returns true if there are more items available to show
  bool hasMoreItems(int displayLimit) => matchingItems.length > displayLimit;
}

/// Aggregates search results from both local (SQLite) and shared (Firestore) sources
/// Results are grouped by list for convenient display
class SearchResultModel {
  /// Keyed by listId; contains grouped items under each list
  final Map<String, GroupedListResult> groupedResults;

  /// Original search query for reference
  final String searchQuery;

  /// Number of total results across all groups
  final int totalResultCount;

  /// Timestamp when search was performed
  final DateTime searchedAt;

  SearchResultModel({
    required this.groupedResults,
    required this.searchQuery,
    this.totalResultCount = 0,
    DateTime? searchedAt,
  }) : searchedAt = searchedAt ?? DateTime.now();

  /// Factory to create empty results
  factory SearchResultModel.empty(String query) {
    return SearchResultModel(
      groupedResults: {},
      searchQuery: query,
      totalResultCount: 0,
    );
  }

  /// Returns total number of matching items (sum across all lists)
  int get totalItems {
    return groupedResults.values.fold(0, (sum, group) => sum + group.itemCount);
  }

  /// Returns total number of lists with results
  int get listCount => groupedResults.length;

  /// Returns list of grouped results sorted by list name
  List<GroupedListResult> getSortedResults() {
    return groupedResults.values.toList()
      ..sort((a, b) => a.list.title.compareTo(b.list.title));
  }

  /// Returns results for a specific list if it exists
  GroupedListResult? getResultsForList(String listId) {
    return groupedResults[listId];
  }

  /// Returns true if there are any results
  bool get hasResults => groupedResults.isNotEmpty;

  /// Returns a summary string for display (e.g., "Found 5 items in 2 lists")
  String getSummaryText() {
    if (!hasResults) {
      return 'No results found';
    }
    final itemWord = totalItems == 1 ? 'item' : 'items';
    final listWord = listCount == 1 ? 'list' : 'lists';
    return 'Found $totalItems $itemWord in $listCount $listWord';
  }

  /// Create a copy with optional overrides
  SearchResultModel copyWith({
    Map<String, GroupedListResult>? groupedResults,
    String? searchQuery,
    int? totalResultCount,
    DateTime? searchedAt,
  }) {
    return SearchResultModel(
      groupedResults: groupedResults ?? this.groupedResults,
      searchQuery: searchQuery ?? this.searchQuery,
      totalResultCount: totalResultCount ?? this.totalResultCount,
      searchedAt: searchedAt ?? this.searchedAt,
    );
  }

  @override
  String toString() =>
      'SearchResultModel(query: "$searchQuery", lists: $listCount, items: $totalItems, at: $searchedAt)';
}
