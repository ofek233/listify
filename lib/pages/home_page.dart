import 'package:flutter/material.dart';
import '../models/folder_model.dart';
import '../models/list_model.dart';
import 'list_detail_page.dart';
import '../widgets/create_list_dialog.dart';
import '../database_helper.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Folder> folders = [];
  List<AppList> lists = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      folders = await _dbHelper.getFolders();
      lists = await _dbHelper.getLists();
      setState(() {});
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Lists'),
      ),

      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: folders.length + 1, // +1 for create folder button
        itemBuilder: (context, index) {
          if (index == 0) {
            return Card(
              child: ListTile(
                leading: const Icon(Icons.create_new_folder),
                title: const Text('Create New Folder'),
                onTap: _showCreateFolderDialog,
              ),
            );
          } else {
            final folderIndex = index - 1;
            final folder = folders[folderIndex];
            final folderLists =
                lists.where((list) => list.folderId == folder.id).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          folder.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'delete') {
                            await _dbHelper.deleteFolder(folder.id);
                            await _loadData();
                          } else if (value == 'rename') {
                            _showRenameDialog(folder);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'rename',
                            child: Text('Rename'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 📄 רשימות בתיקייה
                ...folderLists.map((list) {
                  return Card(
                    child: ListTile(
                      title: Text(list.title),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ListDetailPage(listId: list.id, title: list.title),
                          ),
                        );
                      },
                    ),
                  );
                }),

                const SizedBox(height: 16),
              ],
            );
          }
        },
      ),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => CreateListDialog(
              folders: folders,
              onCreate: (newList) async {
                await _loadData();
              }),
          );
        },
      ),
    );
  }

  void _showRenameDialog(Folder folder) {
    final controller = TextEditingController(text: folder.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Folder name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final updatedFolder = Folder(
                  id: folder.id,
                  name: controller.text.trim(),
                );
                await _dbHelper.updateFolder(updatedFolder);
                await _loadData();
                Navigator.pop(context);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Folder name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final newFolder = Folder(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: controller.text.trim(),
                );
                await _dbHelper.insertFolder(newFolder);
                await _loadData();
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
