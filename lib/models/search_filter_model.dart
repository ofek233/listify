import 'package:flutter/material.dart';
import 'search_query.dart';

/// Represents the state of search filters that can be applied
/// This is used by the filter sheet to manage filter selections
class SearchFilterModel {
  final CompletionStatus completionStatus;
  final DateTimeRange? dateRange;
  final Set<String> selectedListTypes; // empty set = all types
  final String? collaboratorEmail;

  const SearchFilterModel({
    this.completionStatus = CompletionStatus.all,
    this.dateRange,
    Set<String>? selectedListTypes,
    this.collaboratorEmail,
  }) : selectedListTypes = selectedListTypes ?? const {};

  /// Returns true if any filter is non-default
  bool get isActive {
    return completionStatus != CompletionStatus.all ||
        dateRange != null ||
        selectedListTypes.isNotEmpty ||
        collaboratorEmail != null;
  }

  /// Converts filter model to a SearchQuery for querying
  /// Requires baseQuery from the search input
  SearchQuery toSearchQuery(String baseQuery) {
    return SearchQuery(
      baseQuery: baseQuery,
      completionFilter: completionStatus,
      dateRangeStart: dateRange?.start,
      dateRangeEnd: dateRange?.end,
      listTypes: selectedListTypes,
      collaboratorEmail: collaboratorEmail,
    );
  }

  /// Reset all filters to defaults
  SearchFilterModel reset() {
    return const SearchFilterModel();
  }

  /// Create a copy with optional field overrides
  SearchFilterModel copyWith({
    CompletionStatus? completionStatus,
    DateTimeRange? dateRange,
    Set<String>? selectedListTypes,
    String? collaboratorEmail,
    bool clearDateRange = false,
    bool clearCollaborator = false,
  }) {
    return SearchFilterModel(
      completionStatus: completionStatus ?? this.completionStatus,
      dateRange:
          clearDateRange ? null : (dateRange ?? this.dateRange),
      selectedListTypes: selectedListTypes ?? this.selectedListTypes,
      collaboratorEmail: clearCollaborator ? null : (collaboratorEmail ?? this.collaboratorEmail),
    );
  }

  /// Get active filter descriptions for display
  List<String> getActiveFilterDescriptions() {
    final descriptions = <String>[];

    if (completionStatus != CompletionStatus.all) {
      descriptions.add(
        completionStatus == CompletionStatus.completed
            ? 'Completed items only'
            : 'Pending items only',
      );
    }

    if (dateRange != null) {
      final startStr =
          '${dateRange!.start.year}-${dateRange!.start.month.toString().padLeft(2, '0')}-${dateRange!.start.day.toString().padLeft(2, '0')}';
      final endStr =
          '${dateRange!.end.year}-${dateRange!.end.month.toString().padLeft(2, '0')}-${dateRange!.end.day.toString().padLeft(2, '0')}';
      descriptions.add('Date: $startStr to $endStr');
    }

    if (selectedListTypes.isNotEmpty) {
      descriptions.add('Types: ${selectedListTypes.toList().join(", ")}');
    }

    if (collaboratorEmail != null) {
      descriptions.add('Shared with: $collaboratorEmail');
    }

    return descriptions;
  }

  @override
  String toString() =>
      'SearchFilterModel(completionStatus: $completionStatus, dateRange: $dateRange, listTypes: $selectedListTypes, email: $collaboratorEmail)';
}
