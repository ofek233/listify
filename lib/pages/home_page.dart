import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../models/folder_model.dart';
import '../models/list_model.dart';
import '../models/user_model.dart';
import 'list_detail_page.dart';
import 'settings_page.dart';
import '../widgets/create_list_dialog.dart';
import '../widgets/share_folder_dialog.dart';
import '../widgets/share_list_dialog.dart';
import '../database_helper.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'shared_folder_page.dart';
import '../utils/theme_provider.dart';

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
  List<FolderShare> sharedFolders = [];
  List<String> folderOrder = [];
  Map<String, List<String>> listOrderByFolder = {};
  Set<String> expandedFolders = {}; // Track which folders are expanded
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
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = _authService.currentUser;
      if (user != null) {
        // Load preferences first so ordering/theme are applied early
        final prefs = await _firestoreService.getUserPreferences(user.uid);
        _applyUserPreferences(prefs);

        // Load user-specific data from Firestore (cloud)
        try {
          folders = await _firestoreService.getUserFolders(user.uid);
        } catch (e) {
          print('Error loading folders: $e');
          folders = [];
        }

        // Initialize folder order if not set
        if (folderOrder.isEmpty) {
          folderOrder = folders.map((f) => f.id).toList();
        } else {
          // Ensure new folders are added
          for (final f in folders) {
            if (!folderOrder.contains(f.id)) folderOrder.add(f.id);
          }
        }
        
        try {
          lists = await _firestoreService.getUserLists(user.uid);
        } catch (e) {
          print('Error loading lists: $e');
          lists = [];
        }

        // Initialize list order per folder
        for (final folder in folders) {
          final folderLists = lists.where((l) => l.folderId == folder.id).map((l) => l.id).toList();
          final existingOrder = listOrderByFolder[folder.id] ?? [];
          final merged = [...existingOrder];
          for (final id in folderLists) {
            if (!merged.contains(id)) merged.add(id);
          }
          // Remove ids that no longer exist
          listOrderByFolder[folder.id] = merged.where(folderLists.contains).toList();
        }

        // Persist order if missing from user preferences
        if (prefs == null || prefs['folderOrder'] == null || prefs['listOrderByFolder'] == null) {
          await _saveOrderPreferences();
        }
        
        try {
          sharedLists = await _firestoreService.getSharedListsForUser(user.uid);
          print('DEBUG: Loaded ${sharedLists.length} shared lists');
          for (final share in sharedLists) {
            print('  - List: ${share.listId}, Owner: ${share.ownerUserId}, Shared With: ${share.sharedWithUserId}, Role: ${share.role}');
          }
        } catch (e) {
          print('Error loading shared lists: $e');
          sharedLists = [];
        }
        
        try {
          sharedFolders = await _firestoreService.getSharedFoldersForUser(user.uid);
          print('DEBUG: Loaded ${sharedFolders.length} shared folders');
          for (final share in sharedFolders) {
            print('  - Folder: ${share.folderId}, Owner: ${share.ownerUserId}, Shared With: ${share.sharedWithUserId}, Role: ${share.role}');
          }
        } catch (e) {
          print('Error loading shared folders: $e');
          sharedFolders = [];
        }
      }
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _applyUserPreferences(Map<String, dynamic>? prefs) {
    if (prefs == null) return;

    final prefFolderOrder = prefs['folderOrder'] as List<dynamic>?;
    if (prefFolderOrder != null) {
      folderOrder = prefFolderOrder.map((e) => e.toString()).toList();
    }

    final prefListOrder = prefs['listOrderByFolder'] as Map<String, dynamic>?;
    if (prefListOrder != null) {
      listOrderByFolder = prefListOrder.map(
        (key, value) => MapEntry(
          key,
          (value as List<dynamic>).map((e) => e.toString()).toList(),
        ),
      );
    }

    final darkMode = prefs['darkMode'] as bool?;
    if (darkMode != null) {
      final themeProvider = context.read<ThemeProvider>();
      if (themeProvider.isDarkMode != darkMode) {
        themeProvider.setDarkMode(darkMode);
      }
    }
  }

  Future<void> _saveOrderPreferences() async {
    final user = _authService.currentUser;
    if (user == null) return;
    try {
      await _firestoreService.updateUserPreferences(
        user.uid,
        folderOrder: folderOrder,
        listOrderByFolder: listOrderByFolder,
      );
    } catch (e) {
      print('Error saving order preferences: $e');
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
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[300],
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
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => _tabController.index == 0
                ? CreateListDialog(
                    folders: folders,
                    onCreate: (newList) async {
                      await _loadData();
                    },
                  )
                : CreateListDialog(
                    folders: [], // Don't show personal folders in shared tab
                    onCreate: (newList) async {
                      await _loadData();
                    },
                  ),
          );
        },
      ),
    );
  }

  Widget _buildMyListsTab() {
    final orderedFolders = folderOrder
        .map(
          (id) => folders.firstWhere(
            (f) => f.id == id,
            orElse: () => Folder(id: '', name: ''),
          ),
        )
        .where((f) => f.id.isNotEmpty)
        .toList();

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orderedFolders.length + 1,
      onReorder: (oldIndex, newIndex) {
        if (oldIndex == 0 || newIndex == 0) return; // keep create folder static
        if (newIndex > oldIndex) newIndex -= 1;
        setState(() {
          final moved = folderOrder.removeAt(oldIndex - 1);
          folderOrder.insert(newIndex - 1, moved);
        });
        _saveOrderPreferences();
      },
      itemBuilder: (context, index) {
        if (index == 0) {
          return Card(
            key: const ValueKey('create-folder-card'),
            child: ListTile(
              leading: const Icon(Icons.create_new_folder),
              title: const Text('Create New Folder'),
              onTap: _showCreateFolderDialog,
            ),
          );
        }

        final folder = orderedFolders[index - 1];
        final isExpanded = expandedFolders.contains(folder.id);
        final folderLists = lists.where((l) => l.folderId == folder.id).toList();
        final listOrder = listOrderByFolder[folder.id] ?? folderLists.map((l) => l.id).toList();
        final orderedFolderLists = listOrder
            .map(
              (id) => folderLists.firstWhere(
                (l) => l.id == id,
                orElse: () => AppList(id: '', title: '', folderId: ''),
              ),
            )
            .where((l) => l.id.isNotEmpty)
            .toList();

        return Column(
          key: ValueKey('folder-${folder.id}'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                    onPressed: () {
                      setState(() {
                        if (isExpanded) {
                          expandedFolders.remove(folder.id);
                        } else {
                          expandedFolders.add(folder.id);
                        }
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      folder.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'delete') {
                            await _dbHelper.deleteFolder(folder.id);
                            await _loadData();
                          } else if (value == 'rename') {
                            _showRenameDialog(folder);
                          } else if (value == 'share') {
                            _showShareFolderDialog(folder);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'rename',
                            child: Text('Rename'),
                          ),
                          const PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(Icons.share, size: 16),
                                SizedBox(width: 8),
                                Text('Share'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isExpanded)
              ReorderableListView.builder(
                key: ValueKey('lists-${folder.id}'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final order = listOrderByFolder[folder.id] ?? orderedFolderLists.map((l) => l.id).toList();
                    final moved = order.removeAt(oldIndex);
                    order.insert(newIndex, moved);
                    listOrderByFolder[folder.id] = order;
                  });
                  _saveOrderPreferences();
                },
                itemCount: orderedFolderLists.length,
                itemBuilder: (context, listIndex) {
                  final list = orderedFolderLists[listIndex];
                  return Card(
                    key: ValueKey('list-${list.id}'),
                    child: ListTile(
                      title: Text(list.title),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'open') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ListDetailPage(
                                      listId: list.id,
                                      title: list.title,
                                    ),
                                  ),
                                );
                              } else if (value == 'move') {
                                if (mounted) {
                                  _showMoveListDialog(list);
                                }
                              } else if (value == 'delete') {
                                try {
                                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                                  // Delete from Firestore
                                  await _firestoreService.deleteList(_authService.currentUser!.uid, list.id);
                                  // Delete from local database (only on non-web)
                                  if (!kIsWeb) {
                                    await _dbHelper.deleteList(list.id);
                                  }
                                  // Remove from local state immediately for instant UI update
                                  if (mounted) {
                                    setState(() {
                                      lists.removeWhere((l) => l.id == list.id);
                                      // Also remove from shared lists if present
                                      sharedLists.removeWhere((s) => s.listId == list.id);
                                    });
                                  }
                                  // Then reload all data to sync
                                  if (mounted) {
                                    await _loadData();
                                  }
                                  // Use saved reference instead of context
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(content: Text('"${list.title}" deleted successfully')),
                                  );
                                } catch (e) {
                                  print('Error deleting list: $e');
                                  try {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error deleting list: $e')),
                                      );
                                    }
                                  } catch (_) {
                                    // Safe to ignore if context is no longer available
                                  }
                                }
                              } else if (value == 'share') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ListDetailPage(
                                      listId: list.id,
                                      title: list.title,
                                    ),
                                  ),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'open',
                                child: Text('Open'),
                              ),
                              const PopupMenuItem(
                                value: 'move',
                                child: Text('Move to folder'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                              const PopupMenuItem(
                                value: 'share',
                                child: Text('Share / Collaborate'),
                              ),
                            ],
                          ),
                          ReorderableDragStartListener(
                            index: listIndex,
                            child: const Icon(Icons.drag_handle),
                          ),
                        ],
                      ),
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
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildSharedTab() {
    if (sharedFolders.isEmpty && sharedLists.isEmpty) {
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
              'No shared items yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Lists and folders shared with you will appear here',
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
      itemCount: sharedFolders.length + sharedLists.length,
      itemBuilder: (context, index) {
        // Show folders first, then lists
        if (index < sharedFolders.length) {
          final folderShare = sharedFolders[index];
          return FutureBuilder<Map<String, dynamic>>(
            future: _getSharedFolderInfo(folderShare),
            builder: (context, snapshot) {
              final folderTitle = snapshot.data?['folderName'] ?? 'Shared Folder';
              final ownerName = snapshot.data?['ownerName'] ?? 'Unknown User';
              
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.folder_shared),
                  title: Text(folderTitle),
                  subtitle: Text(
                    'Shared by $ownerName • ${folderShare.role.toString().split('.').last}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'exit') {
                            final user = _authService.currentUser;
                            if (user != null) {
                              try {
                                print('DEBUG: User clicked exit for folder share: ${folderShare.folderId}');
                                await _firestoreService.removeUserFromFolderShare(
                                  folderShare.folderId,
                                  user.uid,
                                );
                                print('DEBUG: Successfully removed user from folder share');
                                // Reload data to refresh the UI
                                if (mounted) {
                                  await _loadData();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Exited shared folder')),
                                    );
                                  }
                                }
                              } catch (e) {
                                print('ERROR: Failed to exit folder share: $e');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to exit: $e')),
                                  );
                                }
                              }
                            }
                          } else if (value == 'share') {
                            showDialog(
                              context: context,
                              builder: (_) => ShareFolderDialog(
                                folderId: folderShare.folderId,
                                ownerUserId: folderShare.ownerUserId,
                                folderName: folderTitle,
                              ),
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          if (folderShare.role == ShareRole.owner)
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
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SharedFolderPage(
                          folderShare: folderShare,
                          folderName: folderTitle,
                          ownerName: ownerName,
                        ),
                      ),
                    );
                    if (result == true) {
                      _loadData();
                    }
                  },
                ),
              );
            },
          );
        } else {
          final listIndex = index - sharedFolders.length;
          final share = sharedLists[listIndex];
          return FutureBuilder<Map<String, dynamic>>(
            future: _getSharedListInfo(share),
            builder: (context, snapshot) {
              final listTitle = snapshot.data?['listTitle'] ?? 'Shared List';
              final ownerName = snapshot.data?['ownerName'] ?? 'Unknown User';
              
              return Card(
                child: ListTile(
                  title: Text(listTitle),
                  subtitle: Text(
                    'Shared by $ownerName • ${share.role.toString().split('.').last}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'exit') {
                            final user = _authService.currentUser;
                            if (user != null) {
                              try {
                                print('DEBUG: User clicked exit for list share: ${share.listId}');
                                await _firestoreService.removeUserFromListShare(
                                  share.listId,
                                  user.uid,
                                );
                                print('DEBUG: Successfully removed user from list share');
                                // Reload data to refresh the UI
                                if (mounted) {
                                  await _loadData();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Exited shared list')),
                                    );
                                  }
                                }
                              } catch (e) {
                                print('ERROR: Failed to exit list share: $e');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to exit: $e')),
                                  );
                                }
                              }
                            }
                          } else if (value == 'share') {
                            showDialog(
                              context: context,
                              builder: (_) => ShareListDialog(
                                listId: share.listId,
                                ownerUserId: share.ownerUserId,
                              ),
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          if (share.role == ShareRole.owner)
                            const PopupMenuItem(
                              value: 'share',
                              child: Text('Share / Collaborate'),
                            ),
                          const PopupMenuItem(
                            value: 'exit',
                            child: Text('Exit shared list'),
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
                          listId: share.listId,
                          title: listTitle,
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
      },
    );
  }

  Future<Map<String, dynamic>> _getSharedFolderInfo(FolderShare share) async {
    try {
      print('DEBUG: Getting info for shared folder ${share.folderId} from owner ${share.ownerUserId}');
      
      // Try to get from the share document (stored during share creation)
      final info = await _firestoreService.getFolderShareInfo(
        share.folderId,
        share.sharedWithUserId,
      );
      
      if (info != null) {
        print('DEBUG: Folder name: ${info['folderName']}, Owner: ${info['ownerName']}');
        return {
          'folderName': info['folderName'],
          'ownerName': info['ownerName'],
        };
      }
      
      // Fallback if not found in share doc
      return {
        'folderName': 'Shared Folder',
        'ownerName': 'Unknown User',
      };
    } catch (e) {
      print('Error getting shared folder info: $e');
      return {
        'folderName': 'Shared Folder',
        'ownerName': 'Unknown User',
      };
    }
  }

  Future<Map<String, dynamic>> _getSharedListInfo(ListShare share) async {
    try {
      print('DEBUG: Getting info for shared list ${share.listId} from owner ${share.ownerUserId}');
      // Get list title from owner's collection
      final list = await _firestoreService.getList(share.ownerUserId, share.listId);
      print('DEBUG: Retrieved list: ${list?.title}');
      final listTitle = list?.title ?? 'Shared List';
      
      // Get owner's display name/username or email
      final ownerDoc = await _firestoreService.getUserInfo(share.ownerUserId);
      final ownerName = ownerDoc?['displayName'] ?? ownerDoc?['email'] ?? 'Unknown User';
      print('DEBUG: Owner name: $ownerName');
      
      return {
        'listTitle': listTitle,
        'ownerName': ownerName,
      };
    } catch (e) {
      print('Error getting shared list info: $e');
      return {
        'listTitle': 'Shared List',
        'ownerName': 'Unknown User',
      };
    }
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
                final user = _authService.currentUser;
                if (user != null) {
                  final updatedFolder = Folder(
                    id: folder.id,
                    name: controller.text.trim(),
                  );
                  await _firestoreService.updateFolder(user.uid, updatedFolder);
                  await _loadData();
                }
                Navigator.pop(context);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showMoveListDialog(AppList list) {
    final user = _authService.currentUser;
    if (user == null) return;

    String? selectedFolderId = list.folderId;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Move List'),
        content: DropdownButtonFormField<String>(
          initialValue: selectedFolderId?.isEmpty ?? true ? null : selectedFolderId,
          items: [
            const DropdownMenuItem(
              value: '',
              child: Text('No Folder'),
            ),
            ...folders.map(
              (f) => DropdownMenuItem(
                value: f.id,
                child: Text(f.name),
              ),
            ),
          ],
          onChanged: (val) {
            selectedFolderId = val ?? '';
          },
          decoration: const InputDecoration(labelText: 'Destination folder'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Close dialog immediately for smooth UI
              Navigator.pop(context);
              
              // Perform async operations in background
              _performMoveList(list, selectedFolderId ?? '', user.uid);
            },
            child: const Text('Move'),
          ),
        ],
      ),
    );
  }

  Future<void> _performMoveList(AppList list, String newFolderId, String userId) async {
    try {
      final updated = list.copyWith(folderId: newFolderId);
      
      // Update Firestore
      await _firestoreService.updateList(userId, updated);
      
      // Update local database (only on non-web)
      if (!kIsWeb) {
        await _dbHelper.updateList(updated);
      }
      
      // Reload data to refresh UI
      if (mounted) {
        await _loadData();
        await _saveOrderPreferences();
      }
    } catch (e) {
      print('Error moving list: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error moving list: $e')),
        );
      }
    }
  }

  void _showShareFolderDialog(Folder folder) {
    final user = _authService.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (_) => ShareFolderDialog(
        folderId: folder.id,
        ownerUserId: user.uid,
        folderName: folder.name,
      ),
    ).then((_) => _loadData());
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
