import 'package:flutter/material.dart';
import '../models/folder_model.dart';
import '../models/list_model.dart';
import '../models/list_type.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'recurring_timer_setup_dialog.dart';

class CreateListDialog extends StatefulWidget {
  final List<Folder> folders;
  final Future<void> Function(AppList) onCreate;

  const CreateListDialog({
    super.key,
    required this.folders,
    required this.onCreate,
  });

  @override
  State<CreateListDialog> createState() => _CreateListDialogState();
}

class _CreateListDialogState extends State<CreateListDialog> {
  final TextEditingController _titleController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  late Folder selectedFolder;
  ListType selectedType = ListType.regular;

  @override
  void initState() {
    super.initState();
    selectedFolder = widget.folders.first;
  }

  void _createList() async {
    if (_titleController.text.trim().isEmpty) return;
    
    final user = _authService.currentUser;
    if (user == null) return;

    if (selectedType == ListType.recurring) {
      // Show recurring timer setup dialog
      showDialog(
        context: context,
        builder: (_) => RecurringTimerSetupDialog(
          listTitle: _titleController.text.trim(),
          onCreate: (list) async {
            final completeList = list.copyWith(folderId: selectedFolder.id);
            // Save to Firestore (cloud)
            await _firestoreService.createList(user.uid, completeList);
            await widget.onCreate(completeList);
            Navigator.pop(context); // Close setup dialog
          },
        ),
      );
    } else {
      // Create regular or daily tracker list
      final newList = AppList(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        folderId: selectedFolder.id,
        type: selectedType,
      );

      // Save to Firestore (cloud)
      await _firestoreService.createList(user.uid, newList);
      await widget.onCreate(newList);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create List'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<ListType>(
            initialValue: selectedType,
            items: [
              DropdownMenuItem(
                value: ListType.regular,
                child: const Text('Standard list'),
              ),
              DropdownMenuItem(
                value: ListType.dateBoundPersistent,
                child: const Text('Daily tracker'),
              ),
              DropdownMenuItem(
                value: ListType.recurring,
                child: const Text('Recurring timer'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => selectedType = value);
              }
            },
            decoration: const InputDecoration(
              labelText: 'List type',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'List name',
            ),
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<Folder>(
            initialValue: selectedFolder,
            items: widget.folders
                .map(
                  (folder) => DropdownMenuItem(
                    value: folder,
                    child: Text(folder.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => selectedFolder = value);
              }
            },
            decoration: const InputDecoration(
              labelText: 'Folder',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _createList,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
