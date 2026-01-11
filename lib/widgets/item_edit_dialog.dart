import 'package:flutter/material.dart';
import '../models/list_item_model.dart';
import '../models/item_field_type.dart';
import '../models/list_field_model.dart';
import '../models/list_field_value_model.dart';
import '../models/list_model.dart';
import '../database_helper.dart';

typedef ListItem = ListItemModel;
typedef FieldType = ItemFieldType;

class ItemEditDialog extends StatefulWidget {
  final ListItem item;
  final List<ListField> fields;
  final AppList list;
  final VoidCallback onUpdate;

  const ItemEditDialog({
    super.key,
    required this.item,
    required this.fields,
    required this.list,
    required this.onUpdate,
  });

  @override
  State<ItemEditDialog> createState() => _ItemEditDialogState();
}

class _ItemEditDialogState extends State<ItemEditDialog> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  void _addField() async {
    final nameController = TextEditingController();
    ItemFieldType selectedType = ItemFieldType.shortText;

    final result = await showDialog<ListField>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Field'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration:
                  const InputDecoration(labelText: 'Field name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ItemFieldType>(
              initialValue: selectedType,
              items: ItemFieldType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(type.name),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => selectedType = val);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;

              final newField = ListField(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameController.text.trim(),
                type: selectedType,
                itemId: widget.item.id,
              );

              Navigator.pop(context, newField);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null) {
      final field = result;
      if (widget.list.roleModelItemId == widget.item.id) {
        final applyAll = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Apply to all items?'),
            content: const Text('Do you want to add this field to all items in the list?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Only this')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apply to all')),
            ],
          ),
        );
        if (applyAll == true) {
          final allItems = await _dbHelper.getItemsWithDetails(widget.item.listId);
          for (final other in allItems.where((i) => i.id != widget.item.id)) {
            final existing = other.fields.where((f) => f.name == field.name && f.type == field.type);
            if (existing.isEmpty) {
              final newField = field.copyWith(id: DateTime.now().millisecondsSinceEpoch.toString(), itemId: other.id);
              await _dbHelper.insertField(newField);
              await _dbHelper.insertOrUpdateFieldValue(ListFieldValue(fieldId: newField.id, itemId: other.id, value: null));
            }
          }
        }
      }
      await _dbHelper.insertField(field);
      await _dbHelper.insertOrUpdateFieldValue(ListFieldValue(fieldId: field.id, itemId: widget.item.id, value: null));
      widget.onUpdate();
    }
  }

  void _renameField(ListField field) async {
    final controller = TextEditingController(text: field.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Field'),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Rename')),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      if (widget.list.roleModelItemId == widget.item.id) {
        final allItems = await _dbHelper.getItemsWithDetails(widget.item.listId);
        for (final other in allItems.where((i) => i.id != widget.item.id)) {
          final matchingFields = other.fields.where((f) => f.name == field.name && f.type == field.type);
          if (matchingFields.isNotEmpty) {
            final otherField = matchingFields.first;
            await _dbHelper.updateField(otherField.copyWith(name: newName));
          }
        }
      }
      await _dbHelper.updateField(field.copyWith(name: newName));
      widget.onUpdate();
    }
  }

  void _editFieldValue(ListField field) {
    final valueModel = widget.item.fieldValues.firstWhere(
      (v) => v.fieldId == field.id,
      orElse: () {
        final v = ListFieldValue(
          fieldId: field.id,
          itemId: widget.item.id,
        );
        widget.item.fieldValues.add(v);
        return v;
      },
    );

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(field.name),
          content: _buildFieldEditor(field, valueModel),
          actions: [
            TextButton(
              onPressed: () async {
                await _dbHelper.insertOrUpdateFieldValue(valueModel);
                widget.onUpdate();
                Navigator.pop(context);
              },
              child: const Text("Save"),
            )
          ],
        );
      },
    );
  }

  void _deleteField(ListField field) async {
    if (widget.list.roleModelItemId == widget.item.id) {
      final applyAll = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Apply to all items?'),
          content: const Text('Do you want to delete this field from all items in the list?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Only this')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apply to all')),
          ],
        ),
      );
      if (applyAll == true) {
        final allItems = await _dbHelper.getItemsWithDetails(widget.item.listId);
        for (final other in allItems) {
          final matchingFields = other.fields.where((f) => f.name == field.name && f.type == field.type);
          if (matchingFields.isNotEmpty) {
            final otherField = matchingFields.first;
            await _dbHelper.deleteField(otherField.id, other.id);
          }
        }
      } else {
        await _dbHelper.deleteField(field.id, widget.item.id);
      }
    } else {
      await _dbHelper.deleteField(field.id, widget.item.id);
    }
    widget.onUpdate();
  }

  Widget _buildFieldEditor(
    ListField field,
    ListFieldValue valueModel,
  ) {
    switch (field.type) {
      case ItemFieldType.shortText:
        return TextField(
          controller: TextEditingController(text: valueModel.value?.toString() ?? ''),
          onChanged: (v) => valueModel.value = v,
          decoration: const InputDecoration(hintText: "Enter text"),
        );

      case ItemFieldType.number:
        return TextField(
          controller: TextEditingController(text: valueModel.value?.toString() ?? ''),
          keyboardType: TextInputType.number,
          onChanged: (v) => valueModel.value = int.tryParse(v),
          decoration: const InputDecoration(hintText: "Enter number"),
        );

      case ItemFieldType.yesNo:
        return SwitchListTile(
          title: const Text("Yes / No"),
          value: valueModel.value ?? false,
          onChanged: (v) => setState(() => valueModel.value = v),
        );

      case ItemFieldType.date:
        return ElevatedButton(
          child: Text(
            valueModel.value != null ? (valueModel.value as DateTime).toString() : "Pick date",
          ),
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: valueModel.value ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );
            if (date != null) {
              setState(() => valueModel.value = date);
            }
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.item.title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),

              SwitchListTile(
                title: const Text('Completed'),
                value: widget.item.completed,
                onChanged: (val) {
                  setState(() => widget.item.completed = val);
                  widget.onUpdate();
                },
              ),

              const Divider(),

              ...widget.fields.map((field) {
                final value = widget.item.fieldValues.firstWhere(
                  (v) => v.fieldId == field.id,
                  orElse: () => ListFieldValue(fieldId: field.id, itemId: widget.item.id),
                );
                return ListTile(
                  title: Row(
                    children: [
                      Expanded(child: Text(field.name)),
                      PopupMenuButton<String>(
                        onSelected: (action) async {
                          if (action == 'rename') {
                            _renameField(field);
                          } else if (action == 'delete') {
                            _deleteField(field);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'rename',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 16),
                                SizedBox(width: 8),
                                Text('Rename'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(field.type.name),
                      if (value.value != null)
                        Text(
                          'Value: ${value.value}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                  onTap: () => _editFieldValue(field),
                );
              }),

              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: _addField,
                icon: const Icon(Icons.add),
                label: const Text('Add Field'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
