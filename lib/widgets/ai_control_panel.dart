import 'package:flutter/material.dart';
import '../models/list_item_model.dart';
import '../models/list_field_model.dart';
import '../models/list_field_value_model.dart' as field_value;
import '../models/item_field_type.dart';

typedef ListFieldValueModel = field_value.ListFieldValue;
typedef ListFieldModel = ListField;

enum SortType { numeric, date, alphabetic }
enum SortDirection { ascending, descending }
enum AnalyticsType { sum, average, min, max, count }

class AIControlPanel extends StatefulWidget {
  final List<ListItemModel> items;
  final List<ListFieldModel> fields;
  final Map<String, List<ListFieldValueModel>> fieldValues;
  final Function(List<ListItemModel>) onItemsReordered;

  const AIControlPanel({
    super.key,
    required this.items,
    required this.fields,
    required this.fieldValues,
    required this.onItemsReordered,
  });

  @override
  State<AIControlPanel> createState() => _AIControlPanelState();
}

class _AIControlPanelState extends State<AIControlPanel> {
  ListFieldModel? _selectedField;
  SortType? _selectedSortType;
  SortDirection _sortDirection = SortDirection.ascending;
  AnalyticsType _selectedAnalyticsType = AnalyticsType.sum;
  double? _analyticsResult;
  String? _analyticsResult2;
  String? _analyticsLabel;
  String? _analyticsLabel2;
  bool _isExpanded = true;

  List<ListFieldModel> get _uniqueFields {
    final seen = <String>{};
    final unique = <ListFieldModel>[];
    for (final field in widget.fields) {
      final key = '${field.name}::${field.type}::${field.id}';
      if (seen.add(key)) {
        unique.add(field);
      }
    }
    return unique;
  }

  String? _getMatchingFieldId(ListItemModel item) {
    if (_selectedField == null) return null;

    final matching = item.fields.where(
      (f) => f.name == _selectedField!.name && f.type == _selectedField!.type,
    );
    if (matching.isNotEmpty) return matching.first.id;
    return _selectedField!.id;
  }

  List<ListFieldModel> get numericFields {
    return _uniqueFields.where((f) => f.type == ItemFieldType.number).toList();
  }

  bool get canShowSortButtons => _selectedField != null;

  bool get canShowAnalytics {
    return _selectedField != null && 
        (_selectedField!.type == ItemFieldType.number || 
         _selectedField!.type == ItemFieldType.date ||
         _selectedField!.type == ItemFieldType.yesNo);
  }

  @override
  void didUpdateWidget(covariant AIControlPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_selectedField == null) return;

    final matching = _uniqueFields.where(
      (f) => f.id == _selectedField!.id,
    );
    if (matching.isNotEmpty) {
      if (!identical(matching.first, _selectedField)) {
        setState(() => _selectedField = matching.first);
      }
      return;
    }

    final matchingByNameType = _uniqueFields.where(
      (f) => f.name == _selectedField!.name && f.type == _selectedField!.type,
    );
    if (matchingByNameType.isNotEmpty) {
      setState(() => _selectedField = matchingByNameType.first);
    } else {
      setState(() => _selectedField = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('AI Control Panel'),
            trailing: IconButton(
              icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () => setState(() => _isExpanded = !_isExpanded),
            ),
          ),
          if (_isExpanded) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<ListFieldModel>(
                    decoration: const InputDecoration(
                      labelText: 'Select Field',
                      prefixIcon: Icon(Icons.tag),
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _selectedField,
                    items: _uniqueFields.map((field) {
                      return DropdownMenuItem(
                        value: field,
                        child: Text('${field.name} (${field.type.toString().split('.').last})'),
                      );
                    }).toList(),
                    onChanged: (field) {
                      setState(() {
                        _selectedField = field;
                        _selectedSortType = null;
                        _sortDirection = SortDirection.ascending;
                        _analyticsResult = null;
                        _analyticsResult2 = null;
                        _analyticsLabel = null;
                        _analyticsLabel2 = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  if (canShowSortButtons) ...[
                    ElevatedButton.icon(
                      icon: Icon(_sortDirection == SortDirection.ascending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward),
                      label: const Text('A-Z'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedSortType == SortType.alphabetic
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      onPressed: () => _sortItems(SortType.alphabetic),
                    ),
                    const SizedBox(height: 8),
                    
                    if (_selectedField!.type == ItemFieldType.number)
                      ElevatedButton.icon(
                        icon: Icon(_sortDirection == SortDirection.ascending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward),
                        label: const Text('Numeric'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedSortType == SortType.numeric
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        onPressed: () => _sortItems(SortType.numeric),
                      ),
                    if (_selectedField!.type == ItemFieldType.number)
                      const SizedBox(height: 8),
                    
                    if (_selectedField!.type == ItemFieldType.date)
                      ElevatedButton.icon(
                        icon: Icon(_sortDirection == SortDirection.ascending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward),
                        label: const Text('By Date'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedSortType == SortType.date
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        onPressed: () => _sortItems(SortType.date),
                      ),
                    if (_selectedField!.type == ItemFieldType.date)
                      const SizedBox(height: 8),
                  ],

                  if (canShowAnalytics)
                    DropdownButtonFormField<AnalyticsType>(
                      decoration: const InputDecoration(
                        labelText: 'Analytics Type (for numeric)',
                        prefixIcon: Icon(Icons.bar_chart),
                        border: OutlineInputBorder(),
                      ),
                      initialValue: _selectedAnalyticsType,
                      items: AnalyticsType.values
                          .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.name.toUpperCase()),
                          ))
                          .toList(),
                      onChanged: (type) {
                        if (type != null) {
                          setState(() => _selectedAnalyticsType = type);
                        }
                      },
                    ),
                  if (canShowAnalytics) const SizedBox(height: 12),

                  if (canShowAnalytics)
                    ElevatedButton(
                      onPressed: () => _calculateAnalytics(),
                      child: const Text('Calculate Analytics'),
                    ),
                  
                  if (canShowAnalytics) const SizedBox(height: 16),
                  
                  if (_analyticsLabel != null && _analyticsResult != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _analyticsLabel!,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _analyticsResult!.toStringAsFixed(2),
                            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_analyticsLabel2 != null && _analyticsResult2 != null) ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 16),
                            Text(
                              _analyticsLabel2!,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _analyticsResult2!,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  if (numericFields.isNotEmpty)
                    Chip(
                      avatar: const Icon(Icons.functions, size: 16),
                      label: Text('${numericFields.length} numeric fields'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _sortItems(SortType sortType) {
    if (_selectedField == null) return;
    
    if (_selectedSortType == sortType) {
      _sortDirection = _sortDirection == SortDirection.ascending 
          ? SortDirection.descending 
          : SortDirection.ascending;
    } else {
      _sortDirection = SortDirection.ascending;
    }
    
    setState(() => _selectedSortType = sortType);
    
    final sortedItems = List<ListItemModel>.from(widget.items);
    
    sortedItems.sort((a, b) {
      int compareResult = 0;
      
      switch (sortType) {
        case SortType.alphabetic:
          compareResult = a.title.compareTo(b.title);
          break;
        
        case SortType.numeric:
          final aValue = _getNumericValue(a);
          final bValue = _getNumericValue(b);
          compareResult = aValue.compareTo(bValue);
          break;
        
        case SortType.date:
          final aDate = _getDateValue(a);
          final bDate = _getDateValue(b);
          compareResult = aDate.compareTo(bDate);
          break;
      }
      
      return _sortDirection == SortDirection.ascending 
          ? compareResult 
          : -compareResult;
    });
    
    widget.onItemsReordered(sortedItems);
  }

  void _calculateAnalytics() {
    if (_selectedField == null) return;
    
    setState(() {
      _analyticsResult = null;
      _analyticsResult2 = null;
      _analyticsLabel = null;
      _analyticsLabel2 = null;
    });
    
    switch (_selectedField!.type) {
      case ItemFieldType.number:
        _calculateNumericAnalytics();
        break;
      case ItemFieldType.date:
        _calculateDateAnalytics();
        break;
      case ItemFieldType.yesNo:
        _calculateBooleanAnalytics();
        break;
      default:
        setState(() {
          _analyticsLabel = 'ITEM COUNT';
          _analyticsResult = widget.items.length.toDouble();
        });
    }
  }

  void _calculateNumericAnalytics() {
    if (_selectedField == null) return;
    
    final values = <double>[];
    int itemsWithField = 0;
    
    print('DEBUG: Calculating numeric analytics for field ${_selectedField!.name}');
    print('DEBUG: Total items in list: ${widget.items.length}');
    
    // Collect all numeric values from ALL items in the list
    for (final item in widget.items) {
      final itemFieldValues = widget.fieldValues[item.id] ?? [];

      final matchingFieldId = _getMatchingFieldId(item);
      if (matchingFieldId == null) continue;
      
      // Check if this item has a value for the selected field
      bool hasField = false;
      double value = 0;
      
      for (final fv in itemFieldValues) {
        if (fv.fieldId == matchingFieldId) {
          hasField = true;
          // Parse the value
          if (fv.value != null) {
            if (fv.value is int) {
              value = (fv.value as int).toDouble();
            } else if (fv.value is double) {
              value = fv.value as double;
            } else if (fv.value is String) {
              value = double.tryParse(fv.value.toString()) ?? 0;
            }
          }
          break;
        }
      }
      
      if (hasField) {
        itemsWithField++;
        values.add(value);
        print('DEBUG: Item ${item.id}: has field, value = $value');
      }
    }

    print('DEBUG: Items with field: $itemsWithField, values: $values');

    if (itemsWithField == 0) {
      setState(() {
        _analyticsLabel = 'NO DATA';
        _analyticsResult = 0;
      });
      return;
    }

    switch (_selectedAnalyticsType) {
      case AnalyticsType.sum:
        double sum = values.fold(0.0, (prev, curr) => prev + curr);
        setState(() {
          _analyticsLabel = 'SUM ($itemsWithField Items)';
          _analyticsResult = sum;
        });
        break;
      
      case AnalyticsType.average:
        double sum = values.fold(0.0, (prev, curr) => prev + curr);
        double average = itemsWithField > 0 ? sum / itemsWithField : 0;
        setState(() {
          _analyticsLabel = 'AVERAGE ($itemsWithField Items)';
          _analyticsResult = average;
        });
        break;
      
      case AnalyticsType.min:
        if (values.isNotEmpty) {
          double min = values.reduce((a, b) => a < b ? a : b);
          setState(() {
            _analyticsLabel = 'MINIMUM';
            _analyticsResult = min;
          });
        }
        break;
      
      case AnalyticsType.max:
        if (values.isNotEmpty) {
          double max = values.reduce((a, b) => a > b ? a : b);
          setState(() {
            _analyticsLabel = 'MAXIMUM';
            _analyticsResult = max;
          });
        }
        break;
      
      case AnalyticsType.count:
        // Count all items that have this field (items in the list)
        setState(() {
          _analyticsLabel = 'ITEMS WITH FIELD';
          _analyticsResult = itemsWithField.toDouble();
        });
        break;
    }
  }

  void _calculateDateAnalytics() {
    DateTime? earliestDate;
    DateTime? latestDate;

    for (final item in widget.items) {
      final date = _getDateValue(item);
      if (date != DateTime(1900)) {
        if (earliestDate == null || date.isBefore(earliestDate)) {
          earliestDate = date;
        }
        if (latestDate == null || date.isAfter(latestDate)) {
          latestDate = date;
        }
      }
    }

    setState(() {
      if (earliestDate != null) {
        _analyticsLabel = 'EARLIEST DATE';
        _analyticsResult = earliestDate.millisecondsSinceEpoch.toDouble();
        _analyticsLabel2 = 'LATEST DATE';
        _analyticsResult2 = latestDate?.toString().split(' ')[0] ?? 'N/A';
      } else {
        _analyticsLabel = 'ITEM COUNT';
        _analyticsResult = widget.items.length.toDouble();
      }
    });
  }

  void _calculateBooleanAnalytics() {
    int trueCount = 0;
    int falseCount = 0;

    for (final item in widget.items) {
      final value = _getBooleanValue(item);
      if (value) {
        trueCount++;
      } else {
        falseCount++;
      }
    }

    setState(() {
      _analyticsLabel = 'TRUE COUNT';
      _analyticsResult = trueCount.toDouble();
      _analyticsLabel2 = 'FALSE COUNT';
      _analyticsResult2 = falseCount.toString();
    });
  }

  double _getNumericValue(ListItemModel item) {
    if (_selectedField == null) return 0;
    
    final itemFieldValues = widget.fieldValues[item.id] ?? [];
    final matchingFieldId = _getMatchingFieldId(item);
    if (matchingFieldId == null) return 0;

    print('DEBUG _getNumericValue: Item ${item.id} (${item.title}), looking for field $matchingFieldId, has ${itemFieldValues.length} field values');
    
    // Find the field value for the selected field
    ListFieldValueModel? fieldValue;
    for (final fv in itemFieldValues) {
      print('DEBUG _getNumericValue:   Checking field value: fieldId=${fv.fieldId}, value=${fv.value}, type=${fv.value?.runtimeType}');
      if (fv.fieldId == matchingFieldId) {
        fieldValue = fv;
        print('DEBUG _getNumericValue:   FOUND MATCH!');
        break;
      }
    }
    
    // If no field value found for this item, return 0
    if (fieldValue == null) {
      print('DEBUG _getNumericValue: No field value found for item ${item.id}, returning 0');
      return 0;
    }
    
    if (fieldValue.value == null) {
      print('DEBUG _getNumericValue: Field value is null for item ${item.id}, returning 0');
      return 0;
    }
    
    try {
      // Handle different value types: int, double, String
      if (fieldValue.value is int) {
        final result = (fieldValue.value as int).toDouble();
        print('DEBUG _getNumericValue: Got int ${fieldValue.value}, converted to $result');
        return result;
      } else if (fieldValue.value is double) {
        print('DEBUG _getNumericValue: Got double ${fieldValue.value}');
        return fieldValue.value as double;
      } else if (fieldValue.value is String) {
        final parsed = double.tryParse(fieldValue.value.toString()) ?? 0;
        print('DEBUG _getNumericValue: Got string "${fieldValue.value}", parsed to $parsed');
        return parsed;
      }
      print('DEBUG _getNumericValue: Unknown type ${fieldValue.value?.runtimeType}, returning 0');
      return 0;
    } catch (e) {
      print('Error parsing numeric value for item ${item.id}: $e');
      return 0;
    }
  }

  DateTime _getDateValue(ListItemModel item) {
    if (_selectedField == null) return DateTime(1900);
    
    final itemFieldValues = widget.fieldValues[item.id] ?? [];
    final matchingFieldId = _getMatchingFieldId(item);
    if (matchingFieldId == null) return DateTime(1900);

    ListFieldValueModel? fieldValue;
    for (final fv in itemFieldValues) {
      if (fv.fieldId == matchingFieldId) {
        fieldValue = fv;
        break;
      }
    }
    
    if (fieldValue == null || fieldValue.value == null) return DateTime(1900);
    
    try {
      if (fieldValue.value is DateTime) {
        return fieldValue.value as DateTime;
      } else if (fieldValue.value is String) {
        // Parse ISO8601 string from Firestore
        return DateTime.parse(fieldValue.value.toString());
      }
    } catch (e) {
      print('Error parsing date for item ${item.id}: $e');
    }
    
    return DateTime(1900);
  }

  bool _getBooleanValue(ListItemModel item) {
    if (_selectedField == null) return false;
    
    final itemFieldValues = widget.fieldValues[item.id] ?? [];
    final matchingFieldId = _getMatchingFieldId(item);
    if (matchingFieldId == null) return false;

    final fieldValue = itemFieldValues.firstWhere(
      (fv) => fv.fieldId == matchingFieldId,
      orElse: () => ListFieldValueModel(
        fieldId: matchingFieldId,
        itemId: item.id,
        value: false,
      ),
    );
    
    if (fieldValue.value == null) return false;
    if (fieldValue.value is bool) return fieldValue.value as bool;
    if (fieldValue.value is String) {
      return fieldValue.value.toString().toLowerCase() == 'true';
    }
    return false;
  }
}
