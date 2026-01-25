import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class ShareListDialog extends StatefulWidget {
  final String listId;
  final String ownerUserId;

  const ShareListDialog({
    super.key,
    required this.listId,
    required this.ownerUserId,
  });

  @override
  State<ShareListDialog> createState() => _ShareListDialogState();
}

class _ShareListDialogState extends State<ShareListDialog> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  ShareRole _selectedRole = ShareRole.editor;
  List<ListShare> _shares = [];
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
      final shares = await _firestoreService.getListShares(widget.listId);
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
        setState(() => _errorMessage = 'List already shared with this user');
        return;
      }

      await _firestoreService.shareListWithUser(
        listId: widget.listId,
        ownerUserId: widget.ownerUserId,
        targetUserId: targetUser.uid,
        targetEmail: email,
        role: _selectedRole,
      );

      _emailController.clear();
      await _loadShares();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('List shared successfully')),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to share list');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateShareRole(String shareId, ShareRole newRole) async {
    try {
      await _firestoreService.updateShareRole(
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
      await _firestoreService.removeShare(shareId);
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
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.people, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Share List',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Permission Levels Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Permission Levels',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPermissionLevel(
                      Icons.visibility,
                      'Viewer',
                      'Can only view',
                    ),
                    const SizedBox(height: 6),
                    _buildPermissionLevel(
                      Icons.edit,
                      'Editor',
                      'Can view & edit items',
                    ),
                    const SizedBox(height: 6),
                    _buildPermissionLevel(
                      Icons.admin_panel_settings,
                      'Owner',
                      'Full control including sharing',
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
                          onChanged: (role) {
                            if (role != null) {
                              setState(() => _selectedRole = role);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _shareWithUser,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Invite'),
                    ),
                  ),
                ],
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade900, fontSize: 12),
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
                          const Icon(Icons.person_outline),
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
    );
  }

  Widget _buildPermissionLevel(IconData icon, String title, String description) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
