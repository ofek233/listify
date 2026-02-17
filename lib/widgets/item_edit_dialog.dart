import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/list_item_model.dart';
import '../models/item_field_type.dart';
import '../models/list_field_model.dart';
import '../models/list_field_value_model.dart';
import '../models/list_model.dart';
import '../database_helper.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

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
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  void _addField() async {
    final nameController = TextEditingController();
    ItemFieldType selectedType = ItemFieldType.shortText;

    final result = await showDialog<ListField>(
      context: context,
      builder: (_) {
        ItemFieldType dialogSelectedType = selectedType;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Field'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Field name'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ItemFieldType>(
                    initialValue: dialogSelectedType,
                    items: ItemFieldType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.name),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => dialogSelectedType = val);
                      }
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
                      type: dialogSelectedType,
                      itemId: widget.item.id,
                    );

                    Navigator.pop(context, newField);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      final field = result;
      final user = _authService.currentUser;
      if (user == null) return;
      
      final ownerUserId = widget.list.ownerId ?? user.uid;
      
      // Check if this field already exists to prevent duplicates
      final fieldExists = widget.item.fields.any(
        (f) => f.name == field.name && f.type == field.type,
      );
      
      if (fieldExists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This field already exists')),
          );
        }
        return;
      }

      try {
        if (!kIsWeb) {
          // Local database for mobile/desktop
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
        } else {
          // Web platform - use Firestore
          // Check if this is a role model item
          bool applyToAll = false;
          if (widget.list.roleModelItemId == widget.item.id) {
            final applyAllResult = await showDialog<bool>(
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
            applyToAll = applyAllResult == true;
          }

          await _firestoreService.createField(
            listId: widget.item.listId,
            itemId: widget.item.id,
            fieldId: field.id,
            name: field.name,
            type: field.type.toString().split('.').last,
            ownerUserId: ownerUserId,
          );
          
          // Initialize empty field value
          await _firestoreService.setFieldValue(
            listId: widget.item.listId,
            itemId: widget.item.id,
            fieldId: field.id,
            ownerUserId: ownerUserId,
            value: null,
          );

          // Update local fields list to display immediately
          widget.item.fields.add(field);
          widget.item.fieldValues.add(ListFieldValue(fieldId: field.id, itemId: widget.item.id, value: null));

          // Apply to all other items on web if needed
          if (applyToAll) {
            final allItems = await _firestoreService.getListItems(widget.item.listId, ownerUserId);
            for (final itemData in allItems) {
              final itemId = itemData['id'] as String;
              if (itemId != widget.item.id) {
                // Check if this item already has this field to prevent duplicates
                final itemFieldsData = await _firestoreService.getItemFields(
                  listId: widget.item.listId,
                  itemId: itemId,
                  ownerUserId: ownerUserId,
                );
                final fieldExists = itemFieldsData.any(
                  (f) => f['name'] == field.name && f['type'] == field.type.toString().split('.').last,
                );
                
                if (!fieldExists) {
                  final newFieldId = '${itemId}_${field.name}_${DateTime.now().millisecondsSinceEpoch}';
                  await _firestoreService.createField(
                    listId: widget.item.listId,
                    itemId: itemId,
                    fieldId: newFieldId,
                    name: field.name,
                    type: field.type.toString().split('.').last,
                    ownerUserId: ownerUserId,
                  );
                  await _firestoreService.setFieldValue(
                    listId: widget.item.listId,
                    itemId: itemId,
                    fieldId: newFieldId,
                    ownerUserId: ownerUserId,
                    value: null,
                  );
                }
              }
            }
          }
        }
        
        widget.onUpdate();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding field: $e')),
          );
        }
      }
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
      try {
        final user = _authService.currentUser;
        if (user == null) return;
        final ownerUserId = widget.list.ownerId ?? user.uid;

        if (!kIsWeb) {
          // Local database
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
        } else {
          // Web - use Firestore
          await _firestoreService.updateField(
            listId: widget.item.listId,
            itemId: widget.item.id,
            fieldId: field.id,
            ownerUserId: ownerUserId,
            data: {'name': newName},
          );
          // Update local field
          field.name = newName;
        }
        
        widget.onUpdate();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error renaming field: $e')),
          );
        }
      }
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
                try {
                  if (!kIsWeb) {
                    await _dbHelper.insertOrUpdateFieldValue(valueModel);
                  } else {
                    // Web - use Firestore
                    final user = _authService.currentUser;
                    if (user != null) {
                      final ownerUserId = widget.list.ownerId ?? user.uid;
                      await _firestoreService.setFieldValue(
                        listId: widget.item.listId,
                        itemId: widget.item.id,
                        fieldId: field.id,
                        ownerUserId: ownerUserId,
                        value: valueModel.value,
                      );
                    }
                  }
                  widget.onUpdate();
                  Navigator.pop(context);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error saving field value: $e')),
                    );
                  }
                }
              },
              child: const Text("Save"),
            )
          ],
        );
      },
    );
  }

  void _deleteField(ListField field) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;
      final ownerUserId = widget.list.ownerId ?? user.uid;

      if (!kIsWeb) {
        // Local database
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
      } else {
        // Web - use Firestore
        bool applyToAll = false;
        if (widget.list.roleModelItemId == widget.item.id) {
          final applyAllResult = await showDialog<bool>(
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
          applyToAll = applyAllResult == true;
        }

        await _firestoreService.deleteField(
          listId: widget.item.listId,
          itemId: widget.item.id,
          fieldId: field.id,
          ownerUserId: ownerUserId,
        );
        // Remove from local lists
        widget.item.fields.removeWhere((f) => f.id == field.id);
        widget.item.fieldValues.removeWhere((v) => v.fieldId == field.id);

        // Apply to all other items on web if needed
        if (applyToAll) {
          final allItems = await _firestoreService.getListItems(widget.item.listId, ownerUserId);
          for (final itemData in allItems) {
            final itemId = itemData['id'] as String;
            if (itemId != widget.item.id) {
              // Get fields for this item
              final itemFields = await _firestoreService.getItemFields(
                listId: widget.item.listId,
                itemId: itemId,
                ownerUserId: ownerUserId,
              );
              // Find and delete matching field
              for (final fieldData in itemFields) {
                if (fieldData['name'] == field.name && fieldData['type'] == field.type.toString().split('.').last) {
                  await _firestoreService.deleteField(
                    listId: widget.item.listId,
                    itemId: itemId,
                    fieldId: fieldData['id'],
                    ownerUserId: ownerUserId,
                  );
                }
              }
            }
          }
        }
      }
      
      widget.onUpdate();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting field: $e')),
        );
      }
    }
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
            valueModel.value != null ? _formatDateValue(valueModel.value) : "Pick date",
          ),
          onPressed: () async {
            try {
              final initialDate = _parseDateValue(valueModel.value) ?? DateTime.now();
              final date = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
              );
              if (date != null) {
                setState(() {
                  // Store as DateTime object (will be converted to ISO8601 string when saving)
                  valueModel.value = date;
                });
              }
            } catch (e) {
              print('Error in date picker: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error selecting date: $e')),
                );
              }
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
                onChanged: (val) async {
                  setState(() => widget.item.completed = val);
                  
                  // Save to database
                  if (!kIsWeb) {
                    await _dbHelper.updateItem(widget.item);
                  }
                  
                  // Sync to Firebase
                  final ownerUserId = widget.list.ownerId ?? _authService.currentUser?.uid;
                  if (ownerUserId != null) {
                    try {
                      await _firestoreService.updateItem(
                        listId: widget.item.listId,
                        itemId: widget.item.id,
                        ownerUserId: ownerUserId,
                        data: {'completed': widget.item.completed},
                      );
                    } catch (e) {
                      print('Error syncing completed status to Firebase: $e');
                    }
                  }
                  
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
                          'Value: ${_formatFieldValueForDisplay(field.type, value.value)}',
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

  // Helper method to parse date values from String or DateTime
  DateTime? _parseDateValue(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        print('Error parsing date: $e');
        return null;
      }
    }
    return null;
  }

  // Helper method to format date values for display
  String _formatDateValue(dynamic value) {
    final date = _parseDateValue(value);
    if (date == null) return "Pick date";
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  // Helper method to format field values for display in subtitle
  String _formatFieldValueForDisplay(ItemFieldType type, dynamic value) {
    if (value == null) return 'None';
    
    switch (type) {
      case ItemFieldType.date:
        return _formatDateValue(value);
      case ItemFieldType.yesNo:
        if (value is bool) return value ? 'Yes' : 'No';
        if (value is String) return value.toLowerCase() == 'true' ? 'Yes' : 'No';
        return value.toString();
      default:
        return value.toString();
    }
  }
}
