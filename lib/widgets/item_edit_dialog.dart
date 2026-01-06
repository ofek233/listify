import 'package:flutter/material.dart';
import '../models/list_item_model.dart';
import '../models/item_field_type.dart';
import '../models/list_field_model.dart';
import '../models/list_field_value_model.dart';

typedef ListItem = ListItemModel;
typedef FieldType = ItemFieldType;

class ItemEditDialog extends StatefulWidget {
  final ListItem item;
  final VoidCallback onUpdate;

  const ItemEditDialog({
    super.key,
    required this.item,
    required this.onUpdate,
  });

  @override
  State<ItemEditDialog> createState() => _ItemEditDialogState();
}

class _ItemEditDialogState extends State<ItemEditDialog> {
  void _addField() {
    showDialog(
      context: context,
      builder: (_) {
        final nameController = TextEditingController();
        ItemFieldType selectedType = ItemFieldType.shortText;

        return AlertDialog(
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
                  if (val != null) selectedType = val;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;

                setState(() {
                  widget.item.fields.add(
                    ListField(
                      id: UniqueKey().toString(),
                      name: nameController.text.trim(),
                      type: selectedType,
                    ),
                  );
                });

                widget.onUpdate();
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _editFieldValue(ListField field) {
    final valueModel = widget.item.fieldValues.firstWhere(
      (v) => v.fieldId == field.id,
      orElse: () {
        final v = ListFieldValue(
          fieldId: field.id,
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
              onPressed: () => Navigator.pop(context),
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

              ...widget.item.fields.map((field) {
                return ListTile(
                  title: Text(field.name),
                  subtitle: Text(field.type.name),
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
