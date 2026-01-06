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
  List<ListField> fields = [];
  bool isSelectionMode = false;
  Set<String> selectedItems = Set<String>();
  List<ListItemModel>? copiedItems;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    items = await _dbHelper.getItemsWithDetails(widget.listId);
    fields = await _dbHelper.getFields(widget.listId);
    setState(() {});
  }

  void _addItem(String name) async {
    final newItem = ListItemModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: name,
      listId: widget.listId,
    );
    await _dbHelper.insertItem(newItem);
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
        title: Row(
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
        actions: isSelectionMode ? [
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
        ] : null,
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
                      await _dbHelper.updateItem(item);
                      setState(() {});
                    },
                  ),
            title: Text(item.title),
            subtitle: fields.isNotEmpty
                ? Text(
                    fields.map((field) {
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
                        fields: fields,
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
                final currentList = lists.firstWhere((l) => l.id == widget.listId);
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
