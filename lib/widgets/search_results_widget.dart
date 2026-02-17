import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../models/search_result_model.dart';
import '../models/list_item_model.dart';

typedef OnListTap = void Function(GroupedListResult group);
typedef OnItemTap = void Function(ListItemModel item, GroupedListResult parentList);

/// Displays search results grouped by list, with folder context
/// Each list header shows how many items match, items are expandable sections
class SearchResultsWidget extends StatefulWidget {
  final SearchResultModel results;
  final OnListTap onListTap;
  final OnItemTap onItemTap;
  final int itemDisplayLimit;

  const SearchResultsWidget({
    Key? key,
    required this.results,
    required this.onListTap,
    required this.onItemTap,
    this.itemDisplayLimit = 5,
  }) : super(key: key);

  @override
  State<SearchResultsWidget> createState() => _SearchResultsWidgetState();
}

class _SearchResultsWidgetState extends State<SearchResultsWidget> {
  late Map<String, bool> _expandedListStates;
  late Map<String, bool> _showAllItemsByList;

  @override
  void initState() {
    super.initState();
    // Initialize all list sections as expanded
    _expandedListStates = {
      for (var listId in widget.results.groupedResults.keys) listId: true
    };
    _showAllItemsByList = {
      for (var listId in widget.results.groupedResults.keys) listId: false
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.results.hasResults) {
      return _buildNoResults();
    }

    return Column(
      children: [
        // Summary banner
        _buildSummaryBanner(),
        // Results list
        Expanded(
          child: ListView.builder(
            itemCount: widget.results.listCount,
            itemBuilder: (context, index) {
              final groupedResults = widget.results.getSortedResults();
              final group = groupedResults[index];
              return _buildListSection(context, group);
            },
          ),
        ),
      ],
    );
  }

  /// Build summary banner showing total results
  Widget _buildSummaryBanner() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: colorScheme.primaryContainer,
      child: Row(
        children: [
          Icon(Icons.search, color: colorScheme.onPrimaryContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.results.getSummaryText(),
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build a collapsible section for a list with matching items
  Widget _buildListSection(BuildContext context, GroupedListResult group) {
    final colorScheme = Theme.of(context).colorScheme;
    final isExpanded = _expandedListStates[group.list.id] ?? true;
    final showAll = _showAllItemsByList[group.list.id] ?? false;
    final displayLimit = showAll ? group.itemCount : widget.itemDisplayLimit;
    final hasMore = !showAll && group.hasMoreItems(widget.itemDisplayLimit);
    final displayItems = group.matchingItems.take(displayLimit).toList();

    return Column(
      children: [
        // List header (clickable)
        GestureDetector(
          onTap: () => widget.onListTap(group),
          child: Container(
            color: colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Expansion indicator
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _expandedListStates[group.list.id] =
                          !(_expandedListStates[group.list.id] ?? true);
                    });
                  },
                  child: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                // List icon
                Icon(
                  Icons.list,
                  color: colorScheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                // List info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.getContextLabel(),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (group.parentFolderName != null)
                        Text(
                          'in ${group.parentFolderName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Result count badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${group.itemCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Items (if expanded)
        if (isExpanded)
          Container(
            color: colorScheme.surface,
            child: Column(
              children: [
                ...displayItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isLast = index == displayItems.length - 1 && !hasMore;

                  return _buildItemTile(context, item, group, isLast);
                }),
                // "View More" button if applicable
                if (hasMore)
                  _buildViewMoreButton(context, group, displayLimit),
              ],
            ),
          ),
        // Divider
        Divider(height: 1, color: colorScheme.outlineVariant),
      ],
    );
  }

  /// Build a single item tile
  Widget _buildItemTile(
    BuildContext context,
    ListItemModel item,
    GroupedListResult parentList,
    bool isLast,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        // Show toast with context
        Fluttertoast.showToast(
          msg: 'Found in ${parentList.list.title}',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: colorScheme.inverseSurface,
          textColor: colorScheme.onInverseSurface,
        );
        // Call callback
        widget.onItemTap(item, parentList);
      },
      child: Container(
        decoration: BoxDecoration(
          border: !isLast
              ? Border(
                  bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
                )
              : null,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        child: Row(
          children: [
            // Checkbox icon or completion indicator
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: item.completed ? Colors.green : colorScheme.outline,
                  width: 2,
                ),
                color: item.completed ? Colors.green : Colors.transparent,
              ),
              child: item.completed
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
            // Item title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface,
                      decoration: item.completed
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Status indicator
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  /// Build "View More" button for lists with many matching items
  Widget _buildViewMoreButton(
    BuildContext context,
    GroupedListResult group,
    int displayLimit,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final remaining = group.itemCount - displayLimit;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Material(
        color: colorScheme.surface,
        child: InkWell(
          onTap: () {
            setState(() {
              _showAllItemsByList[group.list.id] = true;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'View $remaining more items',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build "no results" view
  Widget _buildNoResults() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try different keywords or adjust filters',
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
