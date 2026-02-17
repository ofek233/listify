import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/list_model.dart';
import '../models/list_type.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'list_detail_page.dart';
import '../widgets/share_folder_dialog.dart';
import '../widgets/share_list_dialog.dart';

class SharedFolderPage extends StatefulWidget {
  final FolderShare folderShare;
  final String folderName;
  final String ownerName;

  const SharedFolderPage({
    super.key,
    required this.folderShare,
    required this.folderName,
    required this.ownerName,
  });

  @override
  State<SharedFolderPage> createState() => _SharedFolderPageState();
}

class _SharedFolderPageState extends State<SharedFolderPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  List<AppList> _lists = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists() async {
    setState(() => _loading = true);
    try {
      final allLists = await _firestoreService.getUserLists(widget.folderShare.ownerUserId);
      _lists = allLists.where((l) => l.folderId == widget.folderShare.folderId).toList();
    } catch (e) {
      _lists = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exitShare() async {
    final user = _authService.currentUser;
    if (user == null) return;
    await _firestoreService.removeUserFromFolderShare(widget.folderShare.folderId, user.uid);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _createList() async {
    // Only allow editors/owners to create lists in this shared folder
    if (!(widget.folderShare.role == ShareRole.owner || widget.folderShare.role == ShareRole.editor)) return;
    
    // Show dialog to select list type
    final listType = await showDialog<ListType>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Select List Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Regular'),
              subtitle: const Text('Standard list'),
              onTap: () => Navigator.pop(context, ListType.regular),
            ),
            ListTile(
              title: const Text('Daily Tracker'),
              subtitle: const Text('Track items across dates'),
              onTap: () => Navigator.pop(context, ListType.dateBoundPersistent),
            ),
            ListTile(
              title: const Text('Recurring'),
              subtitle: const Text('Repeating tasks'),
              onTap: () => Navigator.pop(context, ListType.recurring),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    
    if (listType == null) return;
    
    final newList = AppList(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'New List',
      folderId: widget.folderShare.folderId,
      type: listType,
      ownerId: widget.folderShare.ownerUserId,
    );
    await _firestoreService.createList(widget.folderShare.ownerUserId, newList);
    await _loadLists();
  }

  Future<void> _renameList(AppList list) async {
    if (!(widget.folderShare.role == ShareRole.owner || widget.folderShare.role == ShareRole.editor)) return;
    final controller = TextEditingController(text: list.title);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename List'),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    final updated = list.copyWith(title: newName);
    try {
      if (mounted) setState(() => _loading = true);
      await _firestoreService.updateList(widget.folderShare.ownerUserId, updated);
      await _loadLists();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to rename list: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteList(AppList list) async {
    if (!(widget.folderShare.role == ShareRole.owner || widget.folderShare.role == ShareRole.editor)) return;
    await _firestoreService.deleteList(widget.folderShare.ownerUserId, list.id);
    await _loadLists();
  }

  void _showShareFolderDialog() {
    showDialog(
      context: context,
      builder: (_) => ShareFolderDialog(
        folderId: widget.folderShare.folderId,
        ownerUserId: widget.folderShare.ownerUserId,
        folderName: widget.folderName,
      ),
    );
  }

  void _showShareListDialog(AppList list) {
    showDialog(
      context: context,
      builder: (_) => ShareListDialog(
        listId: list.id,
        ownerUserId: widget.folderShare.ownerUserId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.folderShare.role == ShareRole.owner || widget.folderShare.role == ShareRole.editor;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folderName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'exit') {
                _exitShare();
              } else if (value == 'refresh') {
                _loadLists();
              } else if (value == 'share') {
                _showShareFolderDialog();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Text('Refresh'),
              ),
              if (widget.folderShare.role == ShareRole.owner)
                const PopupMenuItem(
                  value: 'share',
                  child: Text('Share / Collaborate'),
                ),
              const PopupMenuItem(
                value: 'exit',
                child: Text('Exit shared folder'),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Shared by ${widget.ownerName} • ${widget.folderShare.role.toString().split('.').last}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _lists.isEmpty
              ? const Center(child: Text('No lists in this folder'))
              : ListView.builder(
                  itemCount: _lists.length,
                  itemBuilder: (context, index) {
                    final list = _lists[index];
                    return Card(
                      child: ListTile(
                        title: Text(list.title),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (canEdit)
                              PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'rename') {
                                    await _renameList(list);
                                  } else if (value == 'delete') {
                                    await _deleteList(list);
                                  } else if (value == 'share') {
                                    _showShareListDialog(list);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'rename',
                                    child: Text('Rename List'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete List'),
                                  ),
                                  if (widget.folderShare.role == ShareRole.owner)
                                    const PopupMenuItem(
                                      value: 'share',
                                      child: Text('Share / Collaborate'),
                                    ),
                                ],
                              ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ListDetailPage(
                                listId: list.id,
                                title: list.title,
                                isShared: true,
                                shareRole: widget.folderShare.role,
                                ownerId: widget.folderShare.ownerUserId,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: _createList,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
