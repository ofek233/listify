import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/folder_model.dart';
import '../models/list_model.dart';
import '../models/user_model.dart';
import 'list_detail_page.dart';
import '../widgets/create_list_dialog.dart';
import '../database_helper.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late final DatabaseHelper _dbHelper = !kIsWeb ? DatabaseHelper() : DatabaseHelper();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  
  List<Folder> folders = [];
  List<AppList> lists = [];
  List<ListShare> sharedLists = [];
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkAuthAndLoadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndLoadData() async {
    final user = _authService.currentUser;
    if (user == null) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
      return;
    }
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = _authService.currentUser;
      if (user != null) {
        // Load user-specific data from Firestore (cloud)
        folders = await _firestoreService.getUserFolders(user.uid);
        lists = await _firestoreService.getUserLists(user.uid);
        sharedLists = await _firestoreService.getSharedListsForUser(user.uid);
      }
      setState(() {});
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listify'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _showSignOutDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Lists'),
            Tab(text: 'Shared'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMyListsTab(),
                _buildSharedTab(),
              ],
            ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              child: const Icon(Icons.add),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => CreateListDialog(
                    folders: folders,
                    onCreate: (newList) async {
                      await _loadData();
                    },
                  ),
                );
              },
            )
          : null,
    );
  }

  Widget _buildMyListsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: folders.length + 1,
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
              ...folderLists.map((list) {
                return Card(
                  child: ListTile(
                    title: Text(list.title),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ListDetailPage(
                            listId: list.id,
                            title: list.title,
                          ),
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
    );
  }

  Widget _buildSharedTab() {
    if (sharedLists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.share,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No shared lists yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Lists shared with you will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sharedLists.length,
      itemBuilder: (context, index) {
        final share = sharedLists[index];
        return Card(
          child: ListTile(
            title: Text(share.listId), // You might want to fetch actual list title
            subtitle: Text(
              'Shared by ${share.sharedByUserId} • ${share.role.toString().split('.').last}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ListDetailPage(
                    listId: share.listId,
                    title: 'Shared List',
                    isShared: true,
                    shareRole: share.role,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _authService.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
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
                final user = _authService.currentUser;
                if (user != null) {
                  final newFolder = Folder(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: controller.text.trim(),
                  );
                  // Save to Firestore (cloud)
                  await _firestoreService.createFolder(user.uid, newFolder);
                  await _loadData();
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
