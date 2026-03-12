import 'package:flutter/material.dart';
import '../models/search_filter_model.dart';

typedef OnSearchFocus = void Function(bool focused);
typedef OnSearchClear = void Function();
typedef OnFilterTap = void Function();

/// Search bar widget with filter button and clear action
class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final OnSearchFocus onFocusChanged;
  final OnSearchClear onClear;
  final OnFilterTap onFilterTap;
  final SearchFilterModel filterModel;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.onFocusChanged,
    required this.onClear,
    required this.onFilterTap,
    required this.filterModel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Focus(
              onFocusChange: onFocusChanged,
              child: TextField(
                controller: controller,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search lists, items, folders...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close, size: 18, color: colorScheme.onSurfaceVariant),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onFilterTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.tune, size: 20, color: colorScheme.onSurfaceVariant),
                if (filterModel.isActive)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
