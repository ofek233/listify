import 'package:flutter/material.dart';
import '../models/folder_model.dart';
import '../models/list_model.dart';
import '../models/list_type.dart';

class CreateListDialog extends StatefulWidget {
  final List<Folder> folders;
  final void Function(AppList) onCreate;

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
  late Folder selectedFolder;

  @override
  void initState() {
    super.initState();
    selectedFolder = widget.folders.first;
  }

  void _createList() {
    if (_titleController.text.trim().isEmpty) return;

    final newList = AppList(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      folderId: selectedFolder.id,
      type: ListType.regular,
    );

    widget.onCreate(newList);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create List'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'List name',
            ),
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<Folder>(
            value: selectedFolder,
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
