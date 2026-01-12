import 'package:flutter/material.dart';
import '../models/list_item_model.dart';
import '../models/list_field_model.dart';
import '../models/list_field_value_model.dart';
import '../models/item_field_type.dart';
import '../models/list_model.dart';
import '../models/list_type.dart';
import '../widgets/item_edit_dialog.dart';
import '../database_helper.dart';

typedef ListItem = ListItemModel;

class ListDetailPage extends StatefulWidget {
  final String listId;
  final String title;

  const ListDetailPage({super.key, required this.listId, required this.title});

  @override
  State<ListDetailPage> createState() => _ListDetailPageState();
}

class _ListDetailPageState extends State<ListDetailPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<ListItemModel> items = [];
  AppList? list;
  bool isSelectionMode = false;
  Set<String> selectedItems = <String>{};
  List<ListItemModel>? copiedItems;
  DateTime currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    list = await _dbHelper.getList(widget.listId);
    items = await _dbHelper.getItemsWithDetails(widget.listId);
    
    // For date-bound lists, load completion status for current date
    if (list?.type == ListType.dateBoundPersistent) {
      for (final item in items) {
        item.completed = await _dbHelper.getItemCompletionForDate(item.id, currentDate);
      }
    }
    
    setState(() {});
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
      default:
        return value!.value.toString();
    }
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
                  Expanded(child: Text(widget.title)),
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
                    ],
                  ),
                ],
              ),
        actions: [
          if (list?.type == ListType.dateBoundPersistent)
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
              ],
            ),
          if (isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: () {
                setState(() {
                  if (selectedItems.length == items.length) {
                    selectedItems.clear();
                  } else {
                    selectedItems = items.map((item) => item.id).toSet();
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: selectedItems.isNotEmpty ? _deleteSelectedItems : null,
            ),
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: selectedItems.isNotEmpty ? _copySelectedItems : null,
            ),
          ],
        ],
      ),
      body: ListView.builder(
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
                  },
          );
        },
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
                  decoration:
                      const InputDecoration(labelText: 'Item name'),
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
      ),
      // floatingActionButton: FloatingActionButton(
      //   child: const Icon(Icons.add),
      //   onPressed: () {
      //     showDialog(
      //       context: context,
      //       builder: (_) {
      //         final controller = TextEditingController();
      //         return AlertDialog(
      //           title: const Text('Add Item'),
      //           content: TextField(
      //             controller: controller,
      //             autofocus: true,
      //             decoration:
      //                 const InputDecoration(labelText: 'Item name'),
      //           ),
      //           actions: [
      //             TextButton(
      //               onPressed: () => Navigator.pop(context),
      //               child: const Text('Cancel'),
      //             ),
      //             ElevatedButton(
      //               onPressed: () {
      //                 if (controller.text.trim().isNotEmpty) {
      //                   _addItem(controller.text.trim());
      //                   Navigator.pop(context);
      //                 }
      //               },
      //               child: const Text('Add'),
      //             ),
      //           ],
      //         );
      //       },
      //     );
      //   },
      // ),
    );
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
              if (controller.text.trim().isNotEmpty) {
                // Get current list to preserve folderId and type
                final lists = await _dbHelper.getLists();
                AppList? currentList;
                try {
                  currentList = lists.firstWhere((l) => l.id == widget.listId);
                } catch (e) {
                  currentList = null;
                }
                if (currentList == null) return;
                final updatedList = AppList(
                  id: widget.listId,
                  title: controller.text.trim(),
                  folderId: currentList.folderId,
                  type: currentList.type,
                );
                await _dbHelper.updateList(updatedList);
                Navigator.pop(context);
                // Navigate back to refresh title
                Navigator.pop(context);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _deleteSelectedItems() async {
    for (final itemId in selectedItems) {
      await _dbHelper.deleteItem(itemId);
    }
    selectedItems.clear();
    await _loadData();
  }

  void _copySelectedItems() {
    copiedItems = items.where((item) => selectedItems.contains(item.id)).toList();
    setState(() {
      isSelectionMode = false;
      selectedItems.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Items copied')),
    );
  }
}
