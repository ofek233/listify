/// Represents a parsed search query with filters extracted from user input
/// 
/// Supports syntax like:
/// - "milk" → baseQuery: "milk"
/// - "milk completed:yes" → baseQuery: "milk", completionFilter: CompletionStatus.completed
/// - "milk is:pending" → baseQuery: "milk", completionFilter: CompletionStatus.pending
enum CompletionStatus {
  all,
  completed,
  pending,
}

class SearchQuery {
  final String baseQuery;
  final CompletionStatus completionFilter;
  final DateTime? dateRangeStart;
  final DateTime? dateRangeEnd;
  final Set<String> listTypes; // empty set means all types
  final String? collaboratorEmail;

  SearchQuery({
    required this.baseQuery,
    this.completionFilter = CompletionStatus.all,
    this.dateRangeStart,
    this.dateRangeEnd,
    Set<String>? listTypes,
    this.collaboratorEmail,
  }) : listTypes = listTypes ?? {};

  /// Parses user input to extract query and filter keywords
  /// 
  /// Recognizes:
  /// - "completed:yes" or "completed:true" for completed items
  /// - "completed:no" or "completed:false" for pending items
  /// - "is:pending" for pending items
  /// - "is:done" for completed items
  /// - Date filters (e.g., "before:2025-12-01") not implemented yet
  static SearchQuery parse(String input) {
    final parts = input.trim().split(' ');
    final queryWords = <String>[];
    CompletionStatus completionStatus = CompletionStatus.all;
    DateTime? dateStart;
    DateTime? dateEnd;
    Set<String> types = {};
    String? email;

    for (final part in parts) {
      if (part.startsWith('completed:')) {
        final value = part.substring('completed:'.length).toLowerCase();
        if (value == 'yes' || value == 'true') {
          completionStatus = CompletionStatus.completed;
        } else if (value == 'no' || value == 'false') {
          completionStatus = CompletionStatus.pending;
        }
      } else if (part.startsWith('is:')) {
        final value = part.substring('is:'.length).toLowerCase();
        if (value == 'done' || value == 'completed') {
          completionStatus = CompletionStatus.completed;
        } else if (value == 'pending' || value == 'active') {
          completionStatus = CompletionStatus.pending;
        }
      } else if (part.startsWith('email:')) {
        email = part.substring('email:'.length);
      } else if (!part.isEmpty) {
        queryWords.add(part);
      }
    }

    return SearchQuery(
      baseQuery: queryWords.join(' '),
      completionFilter: completionStatus,
      dateRangeStart: dateStart,
      dateRangeEnd: dateEnd,
      listTypes: types.isEmpty ? {} : types,
      collaboratorEmail: email,
    );
  }

  /// Returns true if any filters are applied (beyond base query)
  bool hasFilters() {
    return completionFilter != CompletionStatus.all ||
        dateRangeStart != null ||
        dateRangeEnd != null ||
        listTypes.isNotEmpty ||
        collaboratorEmail != null;
  }

  /// Returns display string for active filters
  String getActiveFiltersDisplay() {
    final filters = <String>[];

    if (completionFilter != CompletionStatus.all) {
      filters.add(completionFilter == CompletionStatus.completed
          ? 'Completed'
          : 'Pending');
    }

    if (dateRangeStart != null || dateRangeEnd != null) {
      filters.add('Date Range');
    }

    if (listTypes.isNotEmpty) {
      filters.add('${listTypes.length} Types');
    }

    if (collaboratorEmail != null) {
      filters.add('Shared: $collaboratorEmail');
    }

    return filters.join(' • ');
  }

  SearchQuery copyWith({
    String? baseQuery,
    CompletionStatus? completionFilter,
    DateTime? dateRangeStart,
    DateTime? dateRangeEnd,
    Set<String>? listTypes,
    String? collaboratorEmail,
  }) {
    return SearchQuery(
      baseQuery: baseQuery ?? this.baseQuery,
      completionFilter: completionFilter ?? this.completionFilter,
      dateRangeStart: dateRangeStart ?? this.dateRangeStart,
      dateRangeEnd: dateRangeEnd ?? this.dateRangeEnd,
      listTypes: listTypes ?? this.listTypes,
      collaboratorEmail: collaboratorEmail ?? this.collaboratorEmail,
    );
  }

  @override
  String toString() =>
      'SearchQuery(baseQuery: $baseQuery, completionFilter: $completionFilter, dateRange: $dateRangeStart to $dateRangeEnd, listTypes: $listTypes, email: $collaboratorEmail)';
}
