import 'package:flutter/material.dart';
import 'dart:async';
import '../models/list_item_model.dart';
import '../models/list_field_model.dart';
import '../models/list_field_value_model.dart';
import '../models/item_field_type.dart';
import '../models/list_model.dart';
import '../models/list_type.dart';
import '../models/user_model.dart';
import '../widgets/item_edit_dialog.dart';
import '../widgets/share_list_dialog.dart';
import '../database_helper.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

typedef ListItem = ListItemModel;

class ListDetailPage extends StatefulWidget {
  final String listId;
  final String title;
  final bool isShared;
  final ShareRole? shareRole;

  const ListDetailPage({
    super.key,
    required this.listId,
    required this.title,
    this.isShared = false,
    this.shareRole,
  });

  @override
  State<ListDetailPage> createState() => _ListDetailPageState();
}

class _ListDetailPageState extends State<ListDetailPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  List<ListItemModel> items = [];
  AppList? list;
  bool isSelectionMode = false;
  Set<String> selectedItems = <String>{};
  List<ListItemModel>? copiedItems;
  DateTime currentDate = DateTime.now();
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Update countdown every minute
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (list?.type == ListType.recurring) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      // Load list metadata from Firestore
      final allUserLists = await _firestoreService.getUserLists(user.uid);
      final firebaseList = allUserLists.firstWhere(
        (l) => l.id == widget.listId,
        orElse: () => AppList(
          id: widget.listId,
          title: widget.title,
          folderId: '',
          type: ListType.regular,
        ),
      );
      
      list = firebaseList;
      
      // Load items from local database
      items = await _dbHelper.getItemsWithDetails(widget.listId);
      
      // For date-bound lists, load completion status for current date
      if (list?.type == ListType.dateBoundPersistent) {
        for (final item in items) {
          item.completed = await _dbHelper.getItemCompletionForDate(item.id, currentDate);
        }
      }

      // Handle recurring timer cycle completion
      if (list?.type == ListType.recurring && list?.dueDate != null) {
        final now = DateTime.now();
        DateTime currentDueDate = list!.dueDate!;

        // If repeating and due date has passed, advance to next cycle
        if (list!.isRepeating == true && currentDueDate.isBefore(now)) {
          while (currentDueDate.isBefore(now)) {
            switch (list!.repeatInterval) {
              case RepeatInterval.day:
                currentDueDate = currentDueDate.add(const Duration(days: 1));
                break;
              case RepeatInterval.week:
                currentDueDate = currentDueDate.add(const Duration(days: 7));
                break;
              case RepeatInterval.month:
                currentDueDate = DateTime(
                  currentDueDate.year,
                  currentDueDate.month + 1,
                  currentDueDate.day,
                );
                break;
              default:
                break;
            }
          }

          // Update the list with new due date
          final updatedList = list!.copyWith(dueDate: currentDueDate);
          await _firestoreService.updateList(user.uid, updatedList);
          list = updatedList;

          // Reset items if not saving between cycles
          if (list!.saveItemsBetweenCycles != true) {
            for (final item in items) {
              if (item.completed) {
                item.completed = false;
                await _dbHelper.updateItem(item);
              }
            }
            items = await _dbHelper.getItemsWithDetails(widget.listId);
          }
        }
      }
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error loading list: $e');
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _addItem(String name) async {
    final newItem = ListItemModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: name,
      listId: widget.listId,
    );
    await _dbHelper.insertItem(newItem);
    if (list?.roleModelItemId != null) {
      final roleItem = await _dbHelper.getItem(list!.roleModelItemId!);
      if (roleItem != null) {
        roleItem.fields = await _dbHelper.getFields(roleItem.id);
        for (final field in roleItem.fields) {
          final existing = newItem.fields.where((f) => f.name == field.name && f.type == field.type);
          if (existing.isEmpty) {
            final newField = field.copyWith(id: DateTime.now().millisecondsSinceEpoch.toString(), itemId: newItem.id);
            await _dbHelper.insertField(newField);
            await _dbHelper.insertOrUpdateFieldValue(ListFieldValue(fieldId: newField.id, itemId: newItem.id, value: null));
          }
        }
      }
    }
    await _loadData();
  }

  void _showRenameItemDialog(ListItemModel item) {
    final controller = TextEditingController(text: item.title);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Item'),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await _dbHelper.updateItem(item.copyWith(title: controller.text));
              await _loadData();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _makeRoleModel(ListItemModel item) async {
    if (list == null) return;
    // Set role model
    await _dbHelper.updateList(list!.copyWith(roleModelItemId: item.id));
    // Apply role model fields to all existing items
    await _dbHelper.applyRoleModelFields(widget.listId, item.id);
    // Set order to 0, shift others
    item.order = 0;
    await _dbHelper.updateItem(item);
    await _dbHelper.updateItemsOrder(widget.listId, item.id);
    await _loadData();
  }

  String _getFieldDisplayValue(ListField field, ListFieldValue? value) {
    if (value?.value == null) return '';

    switch (field.type) {
      case ItemFieldType.shortText:
        final text = value!.value.toString();
        final words = text.split(' ');
        return words.length > 2 ? '${words[0]} ${words[1]}...' : text;
      case ItemFieldType.number:
        return value!.value.toString();
      case ItemFieldType.yesNo:
        return value!.value == true ? 'Yes' : 'No';
      case ItemFieldType.date:
        return (value!.value as DateTime?)?.toString().split(' ')[0] ?? '';
    }
  }

  String _getCountdownText() {
    if (list?.type != ListType.recurring || list?.dueDate == null) return '';

    DateTime nextDueDate = list!.dueDate!;
    final now = DateTime.now();

    // If repeating and due date has passed, calculate next cycle
    if (list!.isRepeating == true && nextDueDate.isBefore(now)) {
      while (nextDueDate.isBefore(now)) {
        switch (list!.repeatInterval) {
          case RepeatInterval.day:
            nextDueDate = nextDueDate.add(const Duration(days: 1));
            break;
          case RepeatInterval.week:
            nextDueDate = nextDueDate.add(const Duration(days: 7));
            break;
          case RepeatInterval.month:
            nextDueDate = DateTime(
              nextDueDate.year,
              nextDueDate.month + 1,
              nextDueDate.day,
            );
            break;
          default:
            break;
        }
      }
    }

    final difference = nextDueDate.difference(now);

    if (difference.isNegative) {
      return 'Overdue';
    }

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;

    if (days > 0) {
      return '$days days, $hours hours remaining';
    } else if (hours > 0) {
      return '$hours hours, $minutes minutes remaining';
    } else {
      return '$minutes minutes remaining';
    }
  }

  void _showRenameListDialog() {
    final controller = TextEditingController(text: widget.title);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename List'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'List name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty && list != null) {
                final user = _authService.currentUser;
                if (user != null) {
                  final updatedList = list!.copyWith(title: controller.text.trim());
                  await _firestoreService.updateList(user.uid, updatedList);
                  list = updatedList;
                  Navigator.pop(context);
                  if (mounted) {
                    setState(() {});
                  }
                }
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showShareDialog() {
    final user = _authService.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) => ShareListDialog(
        listId: widget.listId,
        ownerUserId: user.uid,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: list?.type == ListType.dateBoundPersistent
            ? Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      setState(() {
                        currentDate = currentDate.subtract(const Duration(days: 1));
                      });
                      _loadData();
                    },
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: currentDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 730)), // 2 years ago
                          lastDate: DateTime.now().add(const Duration(days: 365)), // 1 year ahead
                        );
                        if (picked != null) {
                          setState(() {
                            currentDate = picked;
                          });
                          _loadData();
                        }
                      },
                      child: Text(
                        '${currentDate.month}/${currentDate.day}/${currentDate.year}',
                        style: const TextStyle(color: Color.fromARGB(255, 23, 20, 228), fontSize: 16),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      setState(() {
                        currentDate = currentDate.add(const Duration(days: 1));
                      });
                      _loadData();
                    },
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(child: Text(list?.title ?? widget.title)),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'rename') {
                        _showRenameListDialog();
                      } else if (value == 'select') {
                        setState(() {
                          isSelectionMode = !isSelectionMode;
                          selectedItems.clear();
                        });
                      } else if (value == 'paste' && copiedItems != null) {
                        await _dbHelper.copyItems(copiedItems!, widget.listId);
                        await _loadData();
                      } else if (value == 'share') {
                        _showShareDialog();
                      }
                    },
                    itemBuilder: (context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem(
                        value: 'rename',
                        child: Text('Rename List'),
                      ),
                      PopupMenuItem(
                        value: 'select',
                        child: Text(isSelectionMode ? 'Cancel Selection' : 'Select Items'),
                      ),
                      if (copiedItems != null)
                        const PopupMenuItem(
                          value: 'paste',
                          child: Text('Paste Items'),
                        ),
                      if (!widget.isShared && list != null) ...[
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              Icon(Icons.share),
                              SizedBox(width: 8),
                              Text('Share / Collaborate'),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
        actions: null,
      ),
      body: list == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          if (list?.type == ListType.recurring) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Column(
                children: [
                  Text(
                    'Time Remaining',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getCountdownText(),
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (list?.isRepeating == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Repeats every ${list!.repeatInterval.toString().split('.').last}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).primaryColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, index) {
                final item = items[index];
                return ListTile(
                  leading: isSelectionMode
                      ? Checkbox(
                          value: selectedItems.contains(item.id),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                selectedItems.add(item.id);
                              } else {
                                selectedItems.remove(item.id);
                              }
                            });
                          },
                        )
                      : Checkbox(
                          value: item.completed,
                          onChanged: (val) async {
                            item.completed = val ?? false;
                            if (list?.type == ListType.dateBoundPersistent) {
                              await _dbHelper.setItemCompletionForDate(item.id, currentDate, item.completed);
                            } else {
                              await _dbHelper.updateItem(item);
                            }
                            setState(() {});
                          },
                        ),
                  title: Row(
                    children: [
                      if (list?.roleModelItemId == item.id) ...[
                        const Icon(Icons.star_rate, size: 16),
                        const SizedBox(width: 4),
                      ],
                      Text(item.title),
                    ],
                  ),
                  subtitle: item.fields.isNotEmpty
                      ? Text(
                          item.fields.map((field) {
                            final value = item.fieldValues.firstWhere(
                              (v) => v.fieldId == field.id,
                              orElse: () => ListFieldValue(fieldId: field.id, itemId: item.id),
                            );
                            final displayValue = _getFieldDisplayValue(field, value.value != null ? value : null);
                            return displayValue.isNotEmpty ? '${field.name}: $displayValue' : null;
                          }).where((s) => s != null).join(', '),
                          style: const TextStyle(fontSize: 12),
                        )
                      : null,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'rename') {
                        _showRenameItemDialog(item);
                      } else if (value == 'role') {
                        _makeRoleModel(item);
                      }
                    },
                    itemBuilder: (context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem(
                        value: 'rename',
                        child: Text('Rename Item'),
                      ),
                      const PopupMenuItem(
                        value: 'role',
                        child: Text('Make Role Model'),
                      ),
                    ],
                  ),
                  onTap: isSelectionMode
                      ? () {
                          setState(() {
                            if (selectedItems.contains(item.id)) {
                              selectedItems.remove(item.id);
                            } else {
                              selectedItems.add(item.id);
                            }
                          });
                        }
                      : () {
                          if (list != null) {
                            showDialog(
                              context: context,
                              builder: (_) => ItemEditDialog(
                                item: item,
                                fields: item.fields,
                                list: list!,
                                onUpdate: () async {
                                  await _loadData();
                                },
                              ),
                            );
                          }
                        },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) {
              final controller = TextEditingController();
              return AlertDialog(
                title: const Text('Add Item'),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Item name'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (controller.text.trim().isNotEmpty) {
                        _addItem(controller.text.trim());
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Add'),
                  ),
                ],
              );
            },
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}