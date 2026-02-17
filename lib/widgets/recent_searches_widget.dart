import 'package:flutter/material.dart';
import '../models/recent_search.dart';

typedef OnSearchTap = void Function(String query);
typedef OnRemoveSearch = void Function(String query);

/// Displays recent search history
/// Shows last 5 searches with timestamps and result counts
/// Users can tap to re-run a search or remove an entry
class RecentSearchesWidget extends StatelessWidget {
  final List<RecentSearch> recentSearches;
  final OnSearchTap onSearchTap;
  final OnRemoveSearch onRemoveSearch;
  final VoidCallback onClearHistory;

  const RecentSearchesWidget({
    Key? key,
    required this.recentSearches,
    required this.onSearchTap,
    required this.onRemoveSearch,
    required this.onClearHistory,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (recentSearches.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              GestureDetector(
                onTap: onClearHistory,
                child: Text(
                  'Clear',
                  style: TextStyle(
                    color: colorScheme.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Recent searches list
        Expanded(
          child: ListView.builder(
            itemCount: recentSearches.length,
            itemBuilder: (context, index) {
              final search = recentSearches[index];
              return _buildSearchTile(context, search);
            },
          ),
        ),
      ],
    );
  }

  /// Build a single search history tile
  Widget _buildSearchTile(BuildContext context, RecentSearch search) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      child: InkWell(
        onTap: () => onSearchTap(search.query),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Row(
            children: [
              // History icon
              Icon(
                Icons.history,
                color: colorScheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 12),
              // Search query and metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Query text
                    Text(
                      search.query,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Metadata (result count and time ago)
                    Row(
                      children: [
                        Text(
                          '${search.resultCount} result${search.resultCount != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          ' • ',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          search.getTimeAgoString(),
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Remove button
              GestureDetector(
                onTap: () => onRemoveSearch(search.query),
                child: Icon(
                  Icons.close,
                  color: colorScheme.onSurfaceVariant,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build empty state view
  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No recent searches',
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your searches will appear here',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
