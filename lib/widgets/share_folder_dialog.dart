import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class ShareFolderDialog extends StatefulWidget {
  final String folderId;
  final String ownerUserId;
  final String folderName;

  const ShareFolderDialog({
    super.key,
    required this.folderId,
    required this.ownerUserId,
    required this.folderName,
  });

  @override
  State<ShareFolderDialog> createState() => _ShareFolderDialogState();
}

class _ShareFolderDialogState extends State<ShareFolderDialog> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  ShareRole _selectedRole = ShareRole.editor;
  List<FolderShare> _shares = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadShares();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadShares() async {
    setState(() => _isLoading = true);
    try {
      final shares = await _firestoreService.getFolderShares(widget.folderId);
      setState(() => _shares = shares);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load shares');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _shareWithUser() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter an email address');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final targetUser = await _authService.getUserByEmail(email);

      if (targetUser == null) {
        setState(() => _errorMessage = 'User not found with this email');
        return;
      }

      // Check if already shared
      final alreadyShared =
          _shares.any((share) => share.sharedWithUserId == targetUser.uid);

      if (alreadyShared) {
        setState(() => _errorMessage = 'Folder already shared with this user');
        return;
      }

      await _firestoreService.shareFolderWithUser(
        folderId: widget.folderId,
        ownerUserId: widget.ownerUserId,
        targetUserId: targetUser.uid,
        targetEmail: email,
        role: _selectedRole,
      );

      _emailController.clear();
      await _loadShares();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Folder shared successfully')),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to share folder');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateShareRole(String shareId, ShareRole newRole) async {
    try {
      await _firestoreService.updateFolderShareRole(
        shareId: shareId,
        newRole: newRole,
      );
      await _loadShares();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update role')),
        );
      }
    }
  }

  Future<void> _removeShare(String shareId) async {
    try {
      await _firestoreService.removeFolderShare(shareId);
      await _loadShares();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Collaborator removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove collaborator')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share "${widget.folderName}"',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Collaborate with others by sharing this folder',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Permission levels info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Permission Levels',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _PermissionLevel(
                            Icons.visibility,
                            'Viewer',
                            'Can view folder contents',
                            Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(height: 6),
                          _PermissionLevel(
                            Icons.edit,
                            'Editor',
                            'Can view & edit folder and lists',
                            Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(height: 6),
                          _PermissionLevel(
                            Icons.admin_panel_settings,
                            'Owner',
                            'Full control including sharing',
                            Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Invite Section
                    const Text(
                      'Invite by email',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        hintText: 'colleague@email.com',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Role',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              DropdownButton<ShareRole>(
                                value: _selectedRole,
                                isExpanded: true,
                                items: ShareRole.values.map((role) {
                                  return DropdownMenuItem(
                                    value: role,
                                    child: Text(
                                      role.toString().split('.').last.toUpperCase(),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedRole = value);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _shareWithUser,
                          child: const Text('Share'),
                        ),
                      ],
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Shared Users List
                    if (_shares.isNotEmpty) ...[
                      const Text(
                        'Shared with',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _shares.length,
                        itemBuilder: (context, index) {
                          final share = _shares[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.folder_shared),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        share.sharedWithEmail ?? 'Unknown',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        share.role
                                            .toString()
                                            .split('.')
                                            .last
                                            .toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Only owner can change roles
                                if (share.ownerUserId ==
                                    _authService.currentUser?.uid) ...[
                                  DropdownButton<ShareRole>(
                                    value: share.role,
                                    items: ShareRole.values.map((role) {
                                      return DropdownMenuItem(
                                        value: role,
                                        child: Text(
                                          role
                                              .toString()
                                              .split('.')
                                              .last
                                              .toUpperCase(),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (newRole) {
                                      if (newRole != null) {
                                        _updateShareRole(share.id, newRole);
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _removeShare(share.id),
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ] else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Not shared with anyone yet',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionLevel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color textColor;

  const _PermissionLevel(
    this.icon,
    this.title,
    this.description,
    this.textColor,
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: textColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: textColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
