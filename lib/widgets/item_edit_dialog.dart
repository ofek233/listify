import 'package:flutter/material.dart';
import '../models/list_item_model.dart';
import '../models/item_field_type.dart';
import '../models/list_field_model.dart';
import '../models/list_field_value_model.dart';
import '../database_helper.dart';

typedef ListItem = ListItemModel;
typedef FieldType = ItemFieldType;

class ItemEditDialog extends StatefulWidget {
  final ListItem item;
  final List<ListField> fields;
  final VoidCallback onUpdate;

  const ItemEditDialog({
    super.key,
    required this.item,
    required this.fields,
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

    final result = await showDialog<bool>(
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
              value: selectedType,
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
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;

              final newField = ListField(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameController.text.trim(),
                type: selectedType,
                listId: widget.item.listId,
              );

              await _dbHelper.insertField(newField);
              widget.onUpdate();
              Navigator.pop(context, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
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
                          } else if (action == 'roleModel') {
                            await _dbHelper.applyRoleModel(widget.item.listId, [field.id]);
                            widget.onUpdate();
                          } else if (action == 'delete') {
                            await _dbHelper.deleteField(field.id);
                            widget.onUpdate();
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
                            value: 'roleModel',
                            child: Text('Make Role Model'),
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

  void _renameField(ListField field) async {
    final controller = TextEditingController(text: field.name);
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Field'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Field name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                field.name = controller.text.trim();
                await _dbHelper.updateField(field);
                widget.onUpdate();
                Navigator.pop(context, true);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }
}
