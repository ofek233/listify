import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../models/search_filter_model.dart';
import '../models/search_query.dart';

typedef OnApplyFilters = void Function(SearchFilterModel filters);

/// ModalBottomSheet for advanced search filtering
/// Allows users to filter by:
/// - Completion status (all/pending/completed)
/// - List types (regular/recurring/dateBoundPersistent)
/// - Date range
/// - Collaborator email
class SearchFiltersSheet extends StatefulWidget {
  final SearchFilterModel initialFilter;
  final OnApplyFilters onApplyFilters;

  const SearchFiltersSheet({
    Key? key,
    required this.initialFilter,
    required this.onApplyFilters,
  }) : super(key: key);

  @override
  State<SearchFiltersSheet> createState() => _SearchFiltersSheetState();
}

class _SearchFiltersSheetState extends State<SearchFiltersSheet> {
  late CompletionStatus _selectedStatus;
  late DateTimeRange? _selectedDateRange;
  late Set<String> _selectedListTypes;
  late TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialFilter.completionStatus;
    _selectedDateRange = widget.initialFilter.dateRange;
    _selectedListTypes = Set.from(widget.initialFilter.selectedListTypes);
    _emailController = TextEditingController(
      text: widget.initialFilter.collaboratorEmail ?? '',
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filters',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(Icons.close, color: colorScheme.onSurface),
                    ),
                  ],
                ),
              ),
              // Filter options
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Completion Status Filter
                    _buildFilterSection(
                      title: 'Completion Status',
                      child: _buildStatusFilter(),
                    ),
                    const SizedBox(height: 24),
                    // List Types Filter
                    _buildFilterSection(
                      title: 'List Types',
                      child: _buildListTypesFilter(),
                    ),
                    const SizedBox(height: 24),
                    // Date Range Filter
                    _buildFilterSection(
                      title: 'Date Range',
                      child: _buildDateRangeFilter(),
                    ),
                    const SizedBox(height: 24),
                    // Collaborator Email Filter
                    _buildFilterSection(
                      title: 'Collaborator Email',
                      child: _buildEmailFilter(),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              // Action buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Reset button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _resetFilters,
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Apply button
                    Expanded(
                      child: FilledButton(
                        onPressed: _applyFilters,
                        child: const Text('Apply Filters'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build a filter section with title and content
  Widget _buildFilterSection({
    required String title,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  /// Build completion status filter with toggle buttons
  Widget _buildStatusFilter() {
    return SegmentedButton<CompletionStatus>(
      segments: const <ButtonSegment<CompletionStatus>>[
        ButtonSegment<CompletionStatus>(
          value: CompletionStatus.all,
          label: Text('All'),
          icon: Icon(Icons.done_all),
        ),
        ButtonSegment<CompletionStatus>(
          value: CompletionStatus.pending,
          label: Text('Pending'),
          icon: Icon(Icons.circle_outlined),
        ),
        ButtonSegment<CompletionStatus>(
          value: CompletionStatus.completed,
          label: Text('Completed'),
          icon: Icon(Icons.check_circle),
        ),
      ],
      selected: <CompletionStatus>{_selectedStatus},
      onSelectionChanged: (Set<CompletionStatus> newSelection) {
        setState(() {
          _selectedStatus = newSelection.first;
        });
      },
    );
  }

  /// Build list types filter with choice chips
  Widget _buildListTypesFilter() {
    final listTypes = [
      ('regular', 'Standard'),
      ('recurring', 'Recurring'),
      ('dateBoundPersistent', 'Date-Bound'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: listTypes.map((type) {
        final isSelected = _selectedListTypes.contains(type.$1);
        return FilterChip(
          label: Text(type.$2),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedListTypes.add(type.$1);
              } else {
                _selectedListTypes.remove(type.$1);
              }
            });
          },
        );
      }).toList(),
    );
  }

  /// Build date range filter
  Widget _buildDateRangeFilter() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedDateRange != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${_selectedDateRange!.start.year}-${_selectedDateRange!.start.month.toString().padLeft(2, '0')}-${_selectedDateRange!.start.day.toString().padLeft(2, '0')} to ${_selectedDateRange!.end.year}-${_selectedDateRange!.end.month.toString().padLeft(2, '0')}-${_selectedDateRange!.end.day.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonal(
                onPressed: _selectDateRange,
                child: const Text('Select Date Range'),
              ),
            ),
            const SizedBox(width: 8),
            if (_selectedDateRange != null)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDateRange = null;
                  });
                },
                child: Icon(
                  Icons.close,
                  color: colorScheme.error,
                  size: 20,
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Build collaborator email filter
  Widget _buildEmailFilter() {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _emailController,
      decoration: InputDecoration(
        hintText: 'Enter email address',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        prefixIcon: Icon(Icons.email, size: 18, color: colorScheme.onSurfaceVariant),
        suffixIcon: _emailController.text.isNotEmpty
            ? GestureDetector(
                onTap: () {
                  _emailController.clear();
                  setState(() {});
                },
                child: Icon(Icons.close, size: 18, color: colorScheme.onSurfaceVariant),
              )
            : null,
      ),
      onChanged: (value) {
        setState(() {});
      },
    );
  }

  /// Show date range picker
  Future<void> _selectDateRange() async {
    final initialDateRange = _selectedDateRange ??
        DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 30)),
          end: DateTime.now(),
        );

    final newDateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: initialDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: InputDecorationTheme(
              constraints: const BoxConstraints(maxHeight: 55),
            ),
          ),
          child: child!,
        );
      },
    );

    if (newDateRange != null) {
      setState(() {
        _selectedDateRange = newDateRange;
      });
    }
  }

  /// Apply filters and close sheet
  void _applyFilters() {
    final newFilters = SearchFilterModel(
      completionStatus: _selectedStatus,
      dateRange: _selectedDateRange,
      selectedListTypes: _selectedListTypes,
      collaboratorEmail: _emailController.text.isEmpty
          ? null
          : _emailController.text,
    );

    Navigator.pop(context);
    widget.onApplyFilters(newFilters);
  }

  /// Reset all filters to defaults
  void _resetFilters() {
    setState(() {
      _selectedStatus = CompletionStatus.all;
      _selectedDateRange = null;
      _selectedListTypes.clear();
      _emailController.clear();
    });

    Fluttertoast.showToast(
      msg: 'Filters reset',
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }
}

/// Show the filters sheet as a modal
void showSearchFiltersSheet(
  BuildContext context, {
  required SearchFilterModel initialFilter,
  required void Function(SearchFilterModel) onApplyFilters,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => SearchFiltersSheet(
      initialFilter: initialFilter,
      onApplyFilters: onApplyFilters,
    ),
  );
}
