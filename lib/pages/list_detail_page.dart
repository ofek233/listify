import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import '../widgets/ai_control_panel.dart';
import '../database_helper.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/pdf_export_service.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

typedef ListItem = ListItemModel;

class ListDetailPage extends StatefulWidget {
  final String listId;
  final String title;
  final bool isShared;
  final ShareRole? shareRole;
  final String? ownerId;  // Optional owner ID for folder-shared lists
  final String? itemIdToHighlight;

  const ListDetailPage({
    super.key,
    required this.listId,
    required this.title,
    this.isShared = false,
    this.shareRole,
    this.ownerId,
    this.itemIdToHighlight,
  });

  @override
  State<ListDetailPage> createState() => _ListDetailPageState();
}

class _ListDetailPageState extends State<ListDetailPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final ScrollController _scrollController = ScrollController();
  List<ListItemModel> items = [];
  AppList? list;
  bool isSelectionMode = false;
  Set<String> selectedItems = <String>{};
  List<ListItemModel>? copiedItems;
  DateTime currentDate = DateTime.now();
  Timer? _countdownTimer;
  Timer? _highlightClearTimer;
  String? _highlightItemId;

  // Check if current user can edit this list
  bool get canEditList {
    // Owner always can edit
    if (!widget.isShared) return true;
    // For shared lists, only editors and owners can edit (viewers cannot)
    return widget.shareRole == ShareRole.editor || widget.shareRole == ShareRole.owner;
  }

  @override
  void initState() {
    super.initState();
    _highlightItemId = widget.itemIdToHighlight;
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
    _highlightClearTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      print('DEBUG: _loadData() called for listId: ${widget.listId}');
      final user = _authService.currentUser;
      if (user == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      // Load list metadata from Firestore
      AppList? firebaseList;
      String? ownerUserId;
      
      if (widget.isShared) {
        // If ownerId is provided (from folder share), use it directly
        if (widget.ownerId != null) {
          ownerUserId = widget.ownerId;
          firebaseList = await _firestoreService.getList(widget.ownerId!, widget.listId);
        } else {
          // For direct list shares, get the share info to find the owner
          final shares = await _firestoreService.getSharedListsForUser(user.uid);
          final share = shares.firstWhere(
            (s) => s.listId == widget.listId,
            orElse: () => throw Exception('Share not found'),
          );
          
          ownerUserId = share.ownerUserId;
          // Load the specific list from the owner's collection
          firebaseList = await _firestoreService.getList(share.ownerUserId, widget.listId);
        }
        
        // If not found, create a default one
        firebaseList ??= AppList(
            id: widget.listId,
            title: widget.title,
            folderId: '',
            type: ListType.regular,
            ownerId: ownerUserId ?? user.uid,
          );
      } else {
        // For own lists, load from current user's collection
        firebaseList = await _firestoreService.getList(user.uid, widget.listId);
        ownerUserId = user.uid;
        
        // If not found, create a default one
        firebaseList ??= AppList(
            id: widget.listId,
            title: widget.title,
            folderId: '',
            type: ListType.regular,
            ownerId: user.uid,
          );
      }
      
      list = firebaseList;
      
      // Load items
      if (!kIsWeb) {
        // For non-web platforms (Android/iOS), use local database
        items = await _dbHelper.getItemsWithDetails(widget.listId);
        print('DEBUG: Loaded ${items.length} items from local DB for list ${widget.listId}');
      } else {
        // On web, load items from Firebase
        if (ownerUserId != null) {
          final firebaseItems = await _firestoreService.getListItems(widget.listId, ownerUserId);
          items = [];
          
          for (var itemData in firebaseItems) {
            final item = ListItemModel(
              id: itemData['id'],
              title: itemData['title'] ?? '',
              listId: widget.listId,
              completed: itemData['completed'] ?? false,
            );
            
            // Load fields for this item
            try {
              final fieldsData = await _firestoreService.getItemFields(
                listId: widget.listId,
                itemId: item.id,
                ownerUserId: ownerUserId,
              );
              
              for (var fieldData in fieldsData) {
                final field = ListField.fromMap(fieldData);
                item.fields.add(field);
              }
              
              // Load field values
              final fieldValuesData = await _firestoreService.getItemFieldValues(
                listId: widget.listId,
                itemId: item.id,
                ownerUserId: ownerUserId,
              );
              
              print('DEBUG: Item ${item.id} loaded ${fieldValuesData.length} field values');
              for (var valueData in fieldValuesData) {
                final fieldValue = ListFieldValue.fromMap(valueData);
                item.fieldValues.add(fieldValue);
                print('DEBUG:   - Field ${fieldValue.fieldId} = ${fieldValue.value}');
              }
            } catch (e) {
              print('Error loading fields for item ${item.id}: $e');
            }
            
            items.add(item);
          }
          
          print('DEBUG: Loaded ${items.length} items from Firebase for list ${widget.listId}');
        }
      }
      
      print('DEBUG: List type: ${list?.type}');
      
      // For date-bound lists, load completion status for current date
      if (list?.type == ListType.dateBoundPersistent) {
        final dateStr = currentDate.toIso8601String().split('T')[0];
        for (final item in items) {
          if (!kIsWeb) {
            item.completed = await _dbHelper.getItemCompletionForDate(item.id, currentDate);
          } else {
            // On web, load from Firestore
            if (ownerUserId != null) {
              item.completed = await _firestoreService.getItemCompletionForDate(
                listId: widget.listId,
                itemId: item.id,
                ownerUserId: ownerUserId,
                date: dateStr,
              );
            }
          }
        }
      }
      
      if (!kIsWeb && list?.type == ListType.dateBoundPersistent) {
        final now = DateTime.now();
        // Parse dueDate from Firestore (might be String)
        DateTime currentDueDate;
        if (list!.dueDate is String) {
          try {
            currentDueDate = DateTime.parse(list!.dueDate.toString());
          } catch (e) {
            print('Error parsing dueDate: $e');
            return; // Skip if we can't parse
          }
        } else {
          currentDueDate = list!.dueDate!;
        }

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
          final ownerUserId = list!.ownerId ?? user.uid;
          await _firestoreService.updateList(ownerUserId, updatedList);
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
        _scrollToHighlightedItem();
      }
    } catch (e) {
      print('Error loading list: $e');
      if (mounted) {
        setState(() {});
        _scrollToHighlightedItem();
      }
    }
  }

  void _scrollToHighlightedItem() {
    if (_highlightItemId == null) return;
    final index = items.indexWhere((item) => item.id == _highlightItemId);
    if (index == -1) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final targetOffset = (index * 72.0).toDouble();
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    });

    _highlightClearTimer?.cancel();
    _highlightClearTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _highlightItemId = null;
        });
      }
    });
  }

  void _addItem(String name) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;
      
      final newItem = ListItemModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: name,
        listId: widget.listId,
      );
      
      // Get the owner's ID (for shared lists, use the owner; for personal lists, use current user)
      final ownerUserId = list?.ownerId ?? user.uid;
      
      // Save to both local DB and Firebase
      if (!kIsWeb) {
        // Save locally
        await _dbHelper.insertItem(newItem);
        
        // Also save to Firebase so it syncs to other users
        try {
          await _firestoreService.createItem(
            listId: widget.listId,
            itemId: newItem.id,
            title: name,
            ownerUserId: ownerUserId,
          );
        } catch (firebaseError) {
          print('Firebase sync error (item may still be saved locally): $firebaseError');
          // Don't fail - item is saved locally, will sync when permissions are fixed
        }
        
        // Apply role model fields if exists
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
      } else {
        // On web, save to Firebase
        await _firestoreService.createItem(
          listId: widget.listId,
          itemId: newItem.id,
          title: name,
          ownerUserId: ownerUserId,
        );
        
        // Apply role model fields on web
        if (list?.roleModelItemId != null) {
          // Find the role model item
          final roleItem = items.firstWhere(
            (i) => i.id == list!.roleModelItemId,
            orElse: () => ListItemModel(id: '', title: '', listId: ''),
          );
          if (roleItem.id.isNotEmpty) {
            // Apply its fields to the new item
            for (final field in roleItem.fields) {
              final newFieldId = '${newItem.id}_${field.name}_${DateTime.now().millisecondsSinceEpoch}';
              await _firestoreService.createField(
                listId: widget.listId,
                itemId: newItem.id,
                fieldId: newFieldId,
                name: field.name,
                type: field.type.toString().split('.').last,
                ownerUserId: ownerUserId,
              );
              // Initialize empty field value
              await _firestoreService.setFieldValue(
                listId: widget.listId,
                itemId: newItem.id,
                fieldId: newFieldId,
                ownerUserId: ownerUserId,
                value: null,
              );
            }
          }
        }
        
        // Reload to get fields
        await _loadData();
        return;
      }
      
      await _loadData();
    } catch (e) {
      print('Error adding item: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating item: $e')),
        );
      }
    }
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
              try {
                final updatedItem = item.copyWith(title: controller.text);
                final ownerUserId = list?.ownerId ?? _authService.currentUser?.uid;
                
                if (!kIsWeb) {
                  // Save locally
                  await _dbHelper.updateItem(updatedItem);
                  // Also sync to Firebase
                  if (ownerUserId != null) {
                    try {
                      await _firestoreService.updateItem(
                        listId: widget.listId,
                        itemId: item.id,
                        ownerUserId: ownerUserId,
                        data: {'title': controller.text},
                      );
                    } catch (firebaseError) {
                      print('Firebase sync error (item updated locally): $firebaseError');
                      // Don't fail - item is updated locally
                    }
                  }
                } else {
                  // On web, update in Firebase and UI
                  if (ownerUserId != null) {
                    await _firestoreService.updateItem(
                      listId: widget.listId,
                      itemId: item.id,
                      ownerUserId: ownerUserId,
                      data: {'title': controller.text},
                    );
                  }
                  final index = items.indexWhere((i) => i.id == item.id);
                  if (index >= 0) {
                    items[index] = updatedItem;
                    setState(() {});
                  }
                }
                if (!kIsWeb) await _loadData();
                Navigator.pop(context);
              } catch (e) {
                print('Error renaming item: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _makeRoleModel(ListItemModel item) async {
    try {
      if (list == null) return;
      final user = _authService.currentUser;
      if (user == null) return;
      // Set role model
      final updatedList = list!.copyWith(roleModelItemId: item.id);
      if (!kIsWeb) {
        await _dbHelper.updateList(updatedList);
      }
      // Update in Firestore using the owner's ID (not current user for shared lists)
      final ownerUserId = list!.ownerId ?? user.uid;
      await _firestoreService.updateList(ownerUserId, updatedList);
      list = updatedList;
      
      // Apply role model fields to all existing items
      if (!kIsWeb) {
        await _dbHelper.applyRoleModelFields(widget.listId, item.id);
      } else {
        // On web, apply to all items via Firestore
        for (final otherItem in items.where((i) => i.id != item.id)) {
          for (final field in item.fields) {
            // Check if field already exists
            final existing = otherItem.fields.where((f) => f.name == field.name && f.type == field.type);
            if (existing.isEmpty) {
              // Sanitize field name - remove spaces and special characters for use in ID
              final sanitizedName = field.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
              final newFieldId = '${otherItem.id}_${sanitizedName}_${DateTime.now().millisecondsSinceEpoch}';
              await _firestoreService.createField(
                listId: widget.listId,
                itemId: otherItem.id,
                fieldId: newFieldId,
                name: field.name,
                type: field.type.toString().split('.').last,
                ownerUserId: ownerUserId,
              );
              await _firestoreService.setFieldValue(
                listId: widget.listId,
                itemId: otherItem.id,
                fieldId: newFieldId,
                ownerUserId: ownerUserId,
                value: null,
              );
            }
          }
        }
        await _loadData();
      }
      
      setState(() {});
    } catch (e) {
      print('Error setting role model: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
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
        if (value!.value is DateTime) {
          return (value.value as DateTime).toString().split(' ')[0];
        }
        if (value.value is String) {
          try {
            return DateTime.parse(value.value.toString()).toString().split(' ')[0];
          } catch (e) {
            print('Error parsing date for display: $e');
            return value.value.toString();
          }
        }
        return value.value.toString();
    }
  }

  String _getCountdownText() {
    if (list?.type != ListType.recurring || list?.dueDate == null) return '';

    // Parse dueDate from Firestore (might be String)
    DateTime nextDueDate;
    if (list!.dueDate is String) {
      try {
        nextDueDate = DateTime.parse(list!.dueDate.toString());
      } catch (e) {
        print('Error parsing dueDate: $e');
        return ''; // Return empty if we can't parse
      }
    } else {
      nextDueDate = list!.dueDate!;
    }
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
                  // Update in Firestore using the owner's ID
                  final ownerUserId = list!.ownerId ?? user.uid;
                  await _firestoreService.updateList(ownerUserId, updatedList);
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
    final ownerUserId = list?.ownerId ?? user.uid;

    showDialog(
      context: context,
      builder: (context) => ShareListDialog(
        listId: widget.listId,
        ownerUserId: ownerUserId,
      ),
    );
  }

  void _showPdfExportDialog() {
    if (list == null) return;

    // Detect current locale for default language selection
    final currentLocale = Intl.getCurrentLocale();
    bool selectedIsRTL = currentLocale.startsWith('he');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Export List as PDF'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select language for PDF:'),
                const SizedBox(height: 16),
                RadioListTile<bool>(
                  title: const Text('Hebrew (RTL)'),
                  value: true,
                  groupValue: selectedIsRTL,
                  onChanged: (value) {
                    setState(() {
                      selectedIsRTL = value ?? true;
                    });
                  },
                ),
                RadioListTile<bool>(
                  title: const Text('English (LTR)'),
                  value: false,
                  groupValue: selectedIsRTL,
                  onChanged: (value) {
                    setState(() {
                      selectedIsRTL = value ?? false;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _exportListToPdf(isRTL: selectedIsRTL);
                },
                icon: const Icon(Icons.download),
                label: const Text('Export'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportListToPdf({required bool isRTL}) async {
    if (list == null || items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(items.isEmpty
              ? 'Cannot export empty list'
              : 'List not loaded. Please try again.'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      // Generate PDF
      final pdf = await PdfExportService.generatePdf(
        appList: list!,
        items: items,
        isRTL: isRTL,
      );

      // Download or share the PDF
      await _downloadOrSharePdf(pdf);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _downloadOrSharePdf(pw.Document pdf) async {
    try {
      final bytes = await pdf.save();

      if (kIsWeb) {
        // Web: Use printing package to download to device
        await Printing.sharePdf(
          bytes: bytes,
          filename: '${list?.title ?? 'list'}.pdf',
        );
      } else {
        // Mobile: Open share sheet
        await Printing.sharePdf(
          bytes: bytes,
          filename: '${list?.title ?? 'list'}.pdf',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF exported successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting PDF: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _deleteItem(ListItemModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Delete "${item.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final user = _authService.currentUser;
      if (user == null) return;
      final ownerUserId = list?.ownerId ?? user.uid;

      if (!kIsWeb) {
        // Clean up local fields/values then delete item
        final fields = await _dbHelper.getFields(item.id);
        for (final field in fields) {
          await _dbHelper.deleteField(field.id, item.id);
          await _dbHelper.deleteFieldValue(field.id, item.id);
        }
        await _dbHelper.deleteItem(item.id);
      } else {
        // Delete Firestore fields/values, then item
        final fieldData = await _firestoreService.getItemFields(
          listId: widget.listId,
          itemId: item.id,
          ownerUserId: ownerUserId,
        );
        for (final field in fieldData) {
          final fieldId = field['id']?.toString();
          if (fieldId != null) {
            await _firestoreService.deleteField(
              listId: widget.listId,
              itemId: item.id,
              fieldId: fieldId,
              ownerUserId: ownerUserId,
            );
          }
        }
        await _firestoreService.deleteItem(
          listId: widget.listId,
          itemId: item.id,
          ownerUserId: ownerUserId,
        );
      }

      if (list?.roleModelItemId == item.id) {
        final updatedList = list!.copyWith(roleModelItemId: null);
        if (!kIsWeb) {
          await _dbHelper.updateList(updatedList);
        }
        await _firestoreService.updateList(ownerUserId, updatedList);
        list = updatedList;
      }

      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting item: $e')),
        );
      }
    }
  }

  // Get all unique fields from role model item
  List<ListField> _getAllFields() {
    if (list?.roleModelItemId == null) return [];
    
    final roleModelItem = items.firstWhere(
      (i) => i.id == list!.roleModelItemId,
      orElse: () => ListItemModel(id: '', title: '', listId: widget.listId),
    );
    
    return roleModelItem.fields;
  }

  Map<String, List<ListFieldValue>> _getFieldValuesMap() {
    final map = <String, List<ListFieldValue>>{};
    
    for (final item in items) {
      map[item.id] = item.fieldValues;
      print('DEBUG: Building field values map for item ${item.id} (${item.title}): ${item.fieldValues.length} values');
      for (final fv in item.fieldValues) {
        print('DEBUG:   - ${fv.fieldId} = ${fv.value}');
      }
    }
    
    return map;
  }

  // Handle item reordering from AI Control Panel
  void _handleItemsReordered(List<ListItemModel> reorderedItems) {
    setState(() {
      items = reorderedItems;
    });
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
                      } else if (value == 'export_pdf') {
                        _showPdfExportDialog();
                      }
                    },
                    itemBuilder: (context) => <PopupMenuEntry<String>>[
                      if (canEditList)
                        const PopupMenuItem(
                          value: 'rename',
                          child: Text('Rename List'),
                        ),
                      PopupMenuItem(
                        value: 'select',
                        child: Text(isSelectionMode ? 'Cancel Selection' : 'Select Items'),
                      ),
                      if (copiedItems != null && canEditList)
                        const PopupMenuItem(
                          value: 'paste',
                          child: Text('Paste Items'),
                        ),
                      if (list != null &&
                          (list!.ownerId == _authService.currentUser?.uid ||
                              widget.shareRole == ShareRole.owner)) ...[
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
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'export_pdf',
                        child: Row(
                          children: [
                            Icon(Icons.download),
                            SizedBox(width: 8),
                            Text('Export as PDF'),
                          ],
                        ),
                      ),
                    ],
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
                      } else if (value == 'export_pdf') {
                        _showPdfExportDialog();
                      }
                    },
                    itemBuilder: (context) => <PopupMenuEntry<String>>[
                      if (canEditList)
                        const PopupMenuItem(
                          value: 'rename',
                          child: Text('Rename List'),
                        ),
                      PopupMenuItem(
                        value: 'select',
                        child: Text(isSelectionMode ? 'Cancel Selection' : 'Select Items'),
                      ),
                      if (copiedItems != null && canEditList)
                        const PopupMenuItem(
                          value: 'paste',
                          child: Text('Paste Items'),
                        ),
                      // Show share option only to list owners
                        if (list != null &&
                          (list!.ownerId == _authService.currentUser?.uid ||
                            widget.shareRole == ShareRole.owner)) ...[
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
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'export_pdf',
                        child: Row(
                          children: [
                            Icon(Icons.download),
                            SizedBox(width: 8),
                            Text('Export as PDF'),
                          ],
                        ),
                      ),
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
          // AI Control Panel
          if (list?.roleModelItemId != null && _getAllFields().isNotEmpty)
            AIControlPanel(
              items: items,
              fields: _getAllFields(),
              fieldValues: _getFieldValuesMap(),
              onItemsReordered: _handleItemsReordered,
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: items.length,
              itemBuilder: (_, index) {
                final item = items[index];
                final isHighlighted = item.id == _highlightItemId;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  color: isHighlighted ? Colors.yellow.shade100 : Colors.transparent,
                  child: ListTile(
                  leading: isSelectionMode
                      ? Checkbox(
                          value: selectedItems.contains(item.id),
                          onChanged: canEditList ? (val) {
                            setState(() {
                              if (val == true) {
                                selectedItems.add(item.id);
                              } else {
                                selectedItems.remove(item.id);
                              }
                            });
                          } : null,
                        )
                      : Checkbox(
                          value: item.completed,
                          onChanged: canEditList ? (val) async {
                            item.completed = val ?? false;
                            final ownerUserId = list?.ownerId ?? _authService.currentUser?.uid;
                            
                            if (list?.type == ListType.dateBoundPersistent) {
                              // Date-specific completion tracking
                              final dateStr = currentDate.toIso8601String().split('T')[0];
                              if (!kIsWeb) {
                                await _dbHelper.setItemCompletionForDate(item.id, currentDate, item.completed);
                              } else {
                                // On web, save to Firestore
                                if (ownerUserId != null) {
                                  await _firestoreService.setItemCompletionForDate(
                                    listId: widget.listId,
                                    itemId: item.id,
                                    ownerUserId: ownerUserId,
                                    date: dateStr,
                                    completed: item.completed,
                                  );
                                }
                              }
                            } else {
                              if (!kIsWeb) {
                                await _dbHelper.updateItem(item);
                              }
                              // Sync to Firebase
                              if (ownerUserId != null) {
                                try {
                                  await _firestoreService.updateItem(
                                    listId: widget.listId,
                                    itemId: item.id,
                                    ownerUserId: ownerUserId,
                                    data: {'completed': item.completed},
                                  );
                                } catch (firebaseError) {
                                  print('Firebase sync error (item updated locally): $firebaseError');
                                  // Don't fail - item is updated locally
                                }
                              }
                            }
                            setState(() {});
                          } : null,
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
                  trailing: canEditList ? PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'rename') {
                        _showRenameItemDialog(item);
                      } else if (value == 'role') {
                        _makeRoleModel(item);
                      } else if (value == 'delete') {
                        _deleteItem(item);
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
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete Item'),
                      ),
                    ],
                  ) : null,
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
                      : canEditList ? () {
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
                        }
                      : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: canEditList ? FloatingActionButton(
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
      ) : null,
    );
  }
}