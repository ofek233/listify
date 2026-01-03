import 'package:flutter/material.dart';
import '../models/list_item_model.dart';
import '../models/item_field_model.dart';
import '../models/item_field_type.dart';

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
                    ItemField(
                      id: DateTime.now().toString(),
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
