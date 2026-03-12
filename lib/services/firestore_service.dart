import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/list_model.dart';
import '../models/list_type.dart';
import '../models/folder_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  FirebaseFirestore getFirestore() => _firestore;

  // ===================== Folders =====================

  Future<void> createFolder(String userId, Folder folder) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('folders')
        .doc(folder.id)
        .set({
          'name': folder.name,
          'createdAt': DateTime.now().toIso8601String(),
        });
  }

  Future<List<Folder>> getUserFolders(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('folders')
        .get();

    return snapshot.docs
        .map((doc) => Folder(id: doc.id, name: doc['name']))
        .toList();
  }

  Future<void> updateFolder(String userId, Folder folder) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('folders')
        .doc(folder.id)
        .update({'name': folder.name});
  }

  Future<void> deleteFolder(String userId, String folderId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('folders')
        .doc(folderId)
        .delete();
  }

  // ===================== Lists =====================

  Future<void> createList(String userId, AppList list) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('lists')
        .doc(list.id)
        .set({
          'title': list.title,
          'folderId': list.folderId,
          'type': list.type.toString().split('.').last,
          'createdAt': DateTime.now().toIso8601String(),
          'ownerId': userId,
          'roleModelItemId': list.roleModelItemId,
          'dueDate': list.dueDate?.toIso8601String(),
          'isRepeating': list.isRepeating,
          'repeatInterval': list.repeatInterval?.toString().split('.').last,
          'saveItemsBetweenCycles': list.saveItemsBetweenCycles,
        });
  }

  Future<List<AppList>> getUserLists(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('lists')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return AppList(
        id: doc.id,
        title: data['title'],
        folderId: data['folderId'],
        type: _parseListType(data['type']),
        roleModelItemId: data['roleModelItemId'],
        dueDate: data['dueDate'] != null ? DateTime.tryParse(data['dueDate']) : null,
        isRepeating: data['isRepeating'] as bool?,
        repeatInterval: _parseRepeatInterval(data['repeatInterval']),
        saveItemsBetweenCycles: data['saveItemsBetweenCycles'] as bool?,
        ownerId: data['ownerId'] ?? userId,
      );
    }).toList();
  }

  // Get a single list by ID from a specific user's collection
  Future<AppList?> getList(String userId, String listId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('lists')
          .doc(listId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      return AppList(
        id: doc.id,
        title: data['title'],
        folderId: data['folderId'],
        type: _parseListType(data['type']),
        roleModelItemId: data['roleModelItemId'],
        dueDate: data['dueDate'] != null ? DateTime.tryParse(data['dueDate']) : null,
        isRepeating: data['isRepeating'] as bool?,
        repeatInterval: _parseRepeatInterval(data['repeatInterval']),
        saveItemsBetweenCycles: data['saveItemsBetweenCycles'] as bool?,
        ownerId: data['ownerId'] ?? userId,
      );
    } catch (e) {
      print('Error getting list: $e');
      return null;
    }
  }

  ListType _parseListType(String? typeString) {
    if (typeString == null) return ListType.regular;
    try {
      return ListType.values.firstWhere(
        (e) => e.toString().split('.').last == typeString,
        orElse: () => ListType.regular,
      );
    } catch (e) {
      return ListType.regular;
    }
  }

  Future<void> updateList(String userId, AppList list) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('lists')
        .doc(list.id)
        .update({
          'title': list.title,
          'folderId': list.folderId,
          'type': list.type.toString().split('.').last,
          'roleModelItemId': list.roleModelItemId,
          'dueDate': list.dueDate?.toIso8601String(),
          'isRepeating': list.isRepeating,
          'repeatInterval': list.repeatInterval?.toString().split('.').last,
          'saveItemsBetweenCycles': list.saveItemsBetweenCycles,
        });
  }

  RepeatInterval? _parseRepeatInterval(String? value) {
    if (value == null) return null;
    try {
      return RepeatInterval.values.firstWhere(
        (e) => e.toString().split('.').last == value,
        orElse: () => RepeatInterval.day,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteList(String userId, String listId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('lists')
        .doc(listId)
        .delete();
  }

  // ===================== List Sharing =====================

  Future<void> shareListWithUser({
    required String listId,
    required String ownerUserId,
    required String targetUserId,
    required String targetEmail,
    required ShareRole role,
  }) async {
    // Use deterministic ID so security rules can reference it
    final shareId = '${listId}_$targetUserId';

    await _firestore.collection('shares').doc(shareId).set({
      'listId': listId,
      'ownerUserId': ownerUserId,
      'sharedWithUserId': targetUserId,
      'sharedWithEmail': targetEmail,
      'role': role.toString().split('.').last,
      'sharedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> removeUserFromListShare(String listId, String userId) async {
    try {
      print('DEBUG: Removing user $userId from list share $listId');
      final shareId = '${listId}_$userId';
      
      // First try to delete by the constructed ID
      final docRef = _firestore.collection('shares').doc(shareId);
      final docSnapshot = await docRef.get();
      
      if (docSnapshot.exists) {
        await docRef.delete();
        print('DEBUG: Successfully deleted share by ID: $shareId');
        return;
      }
      
      // If not found by ID, query by fields
      print('DEBUG: Share not found by ID, querying by fields');
      final snapshot = await _firestore
          .collection('shares')
          .where('listId', isEqualTo: listId)
          .where('sharedWithUserId', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final docToDelete = snapshot.docs.first;
        print('DEBUG: Found share document: ${docToDelete.id}, deleting it');
        await docToDelete.reference.delete();
        print('DEBUG: Successfully deleted share');
      } else {
        print('DEBUG: No share document found for listId=$listId and userId=$userId');
      }
    } on FirebaseException catch (e) {
      print('ERROR: Firebase exception removing list share: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('ERROR: Unexpected error removing list share: $e');
      rethrow;
    }
  }

  Future<List<ListShare>> getSharedListsForUser(String userId) async {
    try {
      print('DEBUG: Fetching shared lists for user: $userId');
      final snapshot = await _firestore
          .collection('shares')
          .where('sharedWithUserId', isEqualTo: userId)
          .get();

      print('DEBUG: Found ${snapshot.docs.length} shared lists');
      
      // Ensure deterministic share IDs for rules (listId_sharedWithUserId)
      final shares = <ListShare>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        print('DEBUG: Share data: $data');
        final share = ListShare.fromMap(data, doc.id);
        final expectedId = '${share.listId}_${share.sharedWithUserId}';

        // If the doc ID is not deterministic, create/update the deterministic doc
        if (doc.id != expectedId) {
          await _firestore.collection('shares').doc(expectedId).set(data, SetOptions(merge: true));
        }

        shares.add(ListShare.fromMap(data, expectedId));
      }

      return shares;
    } catch (e) {
      print('Error fetching shared lists: $e');
      // If query fails due to permissions or index, try to fetch all shares and filter locally
      try {
        print('DEBUG: Fallback - fetching all shares');
        final snapshot = await _firestore.collection('shares').limit(1000).get();
        final shares = <ListShare>[];
        for (final doc in snapshot.docs) {
          final data = doc.data();
          if (data['sharedWithUserId'] == userId) {
            final share = ListShare.fromMap(data, doc.id);
            final expectedId = '${share.listId}_${share.sharedWithUserId}';
            shares.add(ListShare.fromMap(data, expectedId));
          }
        }
        print('DEBUG: Fallback found ${shares.length} shares');
        return shares;
      } catch (fallbackError) {
        print('Fallback also failed: $fallbackError');
        return [];
      }
    }
  }

  Future<List<ListShare>> getListShares(String listId) async {
    final snapshot = await _firestore
        .collection('shares')
        .where('listId', isEqualTo: listId)
        .get();

    final shares = <ListShare>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final share = ListShare.fromMap(data, doc.id);
      final expectedId = '${share.listId}_${share.sharedWithUserId}';

      if (doc.id != expectedId) {
        await _firestore.collection('shares').doc(expectedId).set(data, SetOptions(merge: true));
      }

      shares.add(ListShare.fromMap(data, expectedId));
    }

    return shares;
  }

  Future<void> updateShareRole({
    required String shareId,
    required ShareRole newRole,
  }) async {
    await _firestore
        .collection('shares')
        .doc(shareId)
        .update({'role': newRole.toString().split('.').last});
  }

  Future<void> removeShare(String shareId) async {
    await _firestore.collection('shares').doc(shareId).delete();
  }

  // Check if user has access to a list
  Future<ShareRole?> getUserAccessToList(
    String listId,
    String userId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('shares')
          .where('listId', isEqualTo: listId)
          .where('sharedWithUserId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        return _parseShareRole(data['role']);
      }
    } catch (e) {
      print('Error checking user access: $e');
    }
    return null;
  }

  ShareRole _parseShareRole(String? roleString) {
    if (roleString == null) return ShareRole.viewer;
    try {
      return ShareRole.values.firstWhere(
        (e) => e.toString().split('.').last == roleString,
        orElse: () => ShareRole.viewer,
      );
    } catch (e) {
      return ShareRole.viewer;
    }
  }

  // Get list details with ownership info
  Future<Map<String, dynamic>?> getListDetails(String listId) async {
    try {
      final snapshot =
          await _firestore.collection('list_metadata').doc(listId).get();
      return snapshot.data();
    } catch (e) {
      print('Error getting list details: $e');
    }
    return null;
  }

  Future<String?> getUserIdByEmail(String email) async {
    try {
      QuerySnapshot query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return query.docs.first.id;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting user info: $e');
      return null;
    }
  }

  Future<void> updateUserEmail(String userId, String newEmail) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'email': newEmail,
      });
    } catch (e) {
      print('Error updating email: $e');
      rethrow;
    }
  }

  Future<void> updateUserDisplayName(String userId, String newDisplayName) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'displayName': newDisplayName,
      });
    } catch (e) {
      print('Error updating display name: $e');
      rethrow;
    }
  }

  // ===================== User Preferences =====================

  Future<Map<String, dynamic>?> getUserPreferences(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      return data['preferences'] as Map<String, dynamic>?;
    } catch (e) {
      print('Error getting user preferences: $e');
      return null;
    }
  }

  Future<void> updateUserPreferences(
    String userId, {
    List<String>? folderOrder,
    Map<String, List<String>>? listOrderByFolder,
    bool? darkMode,
  }) async {
    try {
      final Map<String, dynamic> prefs = {};
      if (folderOrder != null) {
        prefs['folderOrder'] = folderOrder;
      }
      if (listOrderByFolder != null) {
        prefs['listOrderByFolder'] = listOrderByFolder;
      }
      if (darkMode != null) {
        prefs['darkMode'] = darkMode;
      }

      if (prefs.isEmpty) return;

      await _firestore.collection('users').doc(userId).set({
        'preferences': prefs,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating user preferences: $e');
      rethrow;
    }
  }

  // ===================== Folder Sharing =====================

  Future<void> shareFolderWithUser({
    required String folderId,
    required String ownerUserId,
    required String targetUserId,
    required String targetEmail,
    required ShareRole role,
  }) async {
    final shareId = '${folderId}_$targetUserId';
    
    // Get folder name to store in share document
    String folderName = 'Shared Folder';
    try {
      final folders = await getUserFolders(ownerUserId);
      final folder = folders.firstWhere(
        (f) => f.id == folderId,
        orElse: () => Folder(id: folderId, name: 'Shared Folder'),
      );
      folderName = folder.name;
    } catch (e) {
      print('Error fetching folder name: $e');
    }
    
    // Get owner's display name/email
    String ownerName = '';
    try {
      final userInfo = await getUserInfo(ownerUserId);
      ownerName = userInfo?['displayName'] ?? userInfo?['email'] ?? '';
    } catch (e) {
      print('Error fetching owner info: $e');
    }

    await _firestore.collection('folder_shares').doc(shareId).set({
      'folderId': folderId,
      'ownerUserId': ownerUserId,
      'sharedWithUserId': targetUserId,
      'sharedWithEmail': targetEmail,
      'role': role.toString().split('.').last,
      'sharedAt': DateTime.now().toIso8601String(),
      'folderName': folderName,
      'ownerName': ownerName,
    });
  }

  Future<void> removeUserFromFolderShare(String folderId, String userId) async {
    try {
      print('DEBUG: Removing user $userId from folder share $folderId');
      final shareId = '${folderId}_$userId';
      
      // First try to delete by the constructed ID
      final docRef = _firestore.collection('folder_shares').doc(shareId);
      final docSnapshot = await docRef.get();
      
      if (docSnapshot.exists) {
        await docRef.delete();
        print('DEBUG: Successfully deleted folder share by ID: $shareId');
        return;
      }
      
      // If not found by ID, query by fields
      print('DEBUG: Folder share not found by ID, querying by fields');
      final snapshot = await _firestore
          .collection('folder_shares')
          .where('folderId', isEqualTo: folderId)
          .where('sharedWithUserId', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final docToDelete = snapshot.docs.first;
        print('DEBUG: Found folder share document: ${docToDelete.id}, deleting it');
        await docToDelete.reference.delete();
        print('DEBUG: Successfully deleted folder share');
      } else {
        print('DEBUG: No folder share document found for folderId=$folderId and userId=$userId');
      }
    } on FirebaseException catch (e) {
      print('ERROR: Firebase exception removing folder share: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('ERROR: Unexpected error removing folder share: $e');
      rethrow;
    }
  }

  Future<List<FolderShare>> getSharedFoldersForUser(String userId) async {
    try {
      print('DEBUG: Fetching shared folders for user: $userId');
      final snapshot = await _firestore
          .collection('folder_shares')
          .where('sharedWithUserId', isEqualTo: userId)
          .get();

      print('DEBUG: Found ${snapshot.docs.length} shared folders');
      final shares = <FolderShare>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        print('DEBUG: Folder share data: $data');
        final share = FolderShare.fromMap(data, doc.id);
        final expectedId = '${share.folderId}_${share.sharedWithUserId}';

        if (doc.id != expectedId) {
          await _firestore.collection('folder_shares').doc(expectedId).set(data, SetOptions(merge: true));
        }

        shares.add(FolderShare.fromMap(data, expectedId));
      }

      return shares;
    } catch (e) {
      print('Error fetching shared folders: $e');
      // If query fails due to permissions or index, try to fetch all folder_shares and filter locally
      try {
        print('DEBUG: Fallback - fetching all folder shares');
        final snapshot = await _firestore.collection('folder_shares').limit(1000).get();
        final shares = <FolderShare>[];
        for (final doc in snapshot.docs) {
          final data = doc.data();
          if (data['sharedWithUserId'] == userId) {
            final share = FolderShare.fromMap(data, doc.id);
            final expectedId = '${share.folderId}_${share.sharedWithUserId}';
            shares.add(FolderShare.fromMap(data, expectedId));
          }
        }
        print('DEBUG: Fallback found ${shares.length} folders');
        return shares;
      } catch (fallbackError) {
        print('Fallback also failed: $fallbackError');
        return [];
      }
    }
  }

  Future<List<FolderShare>> getFolderShares(String folderId) async {
    final snapshot = await _firestore
        .collection('folder_shares')
        .where('folderId', isEqualTo: folderId)
        .get();

    final shares = <FolderShare>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final share = FolderShare.fromMap(data, doc.id);
      final expectedId = '${share.folderId}_${share.sharedWithUserId}';

      if (doc.id != expectedId) {
        await _firestore.collection('folder_shares').doc(expectedId).set(data, SetOptions(merge: true));
      }

      shares.add(FolderShare.fromMap(data, expectedId));
    }

    return shares;
  }

  Future<void> updateFolderShareRole({
    required String shareId,
    required ShareRole newRole,
  }) async {
    await _firestore
        .collection('folder_shares')
        .doc(shareId)
        .update({'role': newRole.toString().split('.').last});
  }

  Future<void> removeFolderShare(String shareId) async {
    await _firestore.collection('folder_shares').doc(shareId).delete();
  }

  Future<ShareRole?> getUserAccessToFolder(
    String folderId,
    String userId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('folder_shares')
          .where('folderId', isEqualTo: folderId)
          .where('sharedWithUserId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        return _parseShareRole(data['role']);
      }
    } catch (e) {
      print('Error checking folder access: $e');
    }
    return null;
  }

  Future<Map<String, String>?> getFolderShareInfo(
    String folderId,
    String sharedWithUserId,
  ) async {
    try {
      final shareId = '${folderId}_$sharedWithUserId';
      final doc = await _firestore.collection('folder_shares').doc(shareId).get();
      
      if (doc.exists) {
        final data = doc.data()!;
        return {
          'folderName': data['folderName'] ?? 'Shared Folder',
          'ownerName': data['ownerName'] ?? 'Unknown User',
        };
      }
      return null;
    } catch (e) {
      print('Error getting folder share info: $e');
      return null;
    }
  }

  // ===================== Items =====================

  Future<void> createItem({
    required String listId,
    required String itemId,
    required String title,
    required String ownerUserId,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(ownerUserId)
          .collection('lists')
          .doc(listId)
          .collection('items')
          .doc(itemId)
          .set({
            'title': title,
            'completed': false,
            'ownerUserId': ownerUserId,
            'createdAt': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      print('Error creating item: $e');
      rethrow;
    }
  }

  Future<void> updateItem({
    required String listId,
    required String itemId,
    required String ownerUserId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(ownerUserId)
          .collection('lists')
          .doc(listId)
          .collection('items')
          .doc(itemId)
          .update(data);
    } catch (e) {
      print('Error updating item: $e');
      rethrow;
    }
  }

  Future<void> deleteItem({
    required String listId,
    required String itemId,
    required String ownerUserId,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(ownerUserId)
          .collection('lists')
          .doc(listId)
          .collection('items')
          .doc(itemId)
          .delete();
    } catch (e) {
      print('Error deleting item: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getListItems(
    String listId,
    String ownerUserId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(ownerUserId)
          .collection('lists')
          .doc(listId)
          .collection('items')
          .orderBy('createdAt', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => {
            'id': doc.id,
            ...doc.data(),
          })
          .toList();
    } catch (e) {
      print('Error getting list items: $e');
      return [];
    }
  }

  // ============= Field Methods =============

  /// Create a new field for an item
  Future<void> createField({
    required String listId,
    required String itemId,
    required String fieldId,
    required String name,
    required String type,
    required String ownerUserId,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(ownerUserId)
          .collection('lists')
          .doc(listId)
          .collection('items')
          .doc(itemId)
          .collection('fields')
          .doc(fieldId)
          .set({
        'id': fieldId,
        'name': name,
        'type': type,
        'item_id': itemId,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating field: $e');
      rethrow;
    }
  }

  /// Get all fields for an item
  Future<List<Map<String, dynamic>>> getItemFields({
    required String listId,
    required String itemId,
    required String ownerUserId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(ownerUserId)
          .collection('lists')
          .doc(listId)
          .collection('items')
          .doc(itemId)
          .collection('fields')
          .get();

      return snapshot.docs
          .map((doc) => {
            'id': doc.id,
            ...doc.data(),
          })
          .toList();
    } catch (e) {
      print('Error getting item fields: $e');
      return [];
    }
  }

  /// Update a field
  Future<void> updateField({
    required String listId,
    required String itemId,
    required String fieldId,
    required String ownerUserId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(ownerUserId)
          .collection('lists')
          .doc(listId)
          .collection('items')
          .doc(itemId)
          .collection('fields')
          .doc(fieldId)
          .update(data);
    } catch (e) {
      print('Error updating field: $e');
      rethrow;
    }
  }

  /// Delete a field
  Future<void> deleteField({
    required String listId,
    required String itemId,
    required String fieldId,
    required String ownerUserId,
  }) async {
    try {
      // Delete the field
      await _firestore
          .collection('users')
          .doc(ownerUserId)
          .collection('lists')
          .doc(listId)
          .collection('items')
          .doc(itemId)
          .collection('fields')
          .doc(fieldId)
          .delete();

      // Also delete the corresponding field value
      await deleteFieldValue(
        listId: listId,
        itemId: itemId,
        fieldId: fieldId,
        ownerUserId: ownerUserId,
      );
    } catch (e) {
      print('Error deleting field: $e');
      rethrow;
    }
  }

  // ============= Field Value Methods =============

  /// Create or update a field value
  Future<void> setFieldValue({
    required String listId,
    required String itemId,
    required String fieldId,
    required String ownerUserId,
    required dynamic value,
  }) async {
    try {
      // Convert value to storage format
      dynamic storedValue;
      if (value == null) {
        storedValue = null;
      } else if (value is DateTime) {
        // Store DateTime as ISO8601 string
        storedValue = value.toIso8601String();
      } else if (value is bool) {
        // Store bool as bool
        storedValue = value;
      } else if (value is int) {
        // Store int as int
        storedValue = value;
      } else if (value is double) {
        // Store double as double
        storedValue = value;
      } else {
        // Store everything else as string
        storedValue = value.toString();
      }

      await _firestore
          .collection('users')
          .doc(ownerUserId)
          .collection('lists')
          .doc(listId)
          .collection('items')
          .doc(itemId)
          .collection('field_values')
          .doc(fieldId)
          .set({
        'field_id': fieldId,
        'item_id': itemId,
        'value': storedValue,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error setting field value: $e');
      rethrow;
    }
  }

  /// Get all field values for an item
  Future<List<Map<String, dynamic>>> getItemFieldValues({
    required String listId,
    required String itemId,
    required String ownerUserId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(ownerUserId)
          .collection('lists')
          .doc(listId)
          .collection('items')
          .doc(itemId)
          .collection('field_values')
          .get();

      return snapshot.docs
          .map((doc) => {
            'field_id': doc.id,
            ...doc.data(),
          })
          .toList();
    } catch (e) {
      print('Error getting item field values: $e');
      return [];
    }
  }

  /// Delete a field value
  Future<void> deleteFieldValue({
    required String listId,
    required String itemId,
    required String fieldId,
    required String ownerUserId,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(ownerUserId)
          .collection('lists')
          .doc(listId)
          .collection('items')
          .doc(itemId)
          .collection('field_values')
          .doc(fieldId)
          .delete();
    } catch (e) {
      print('Error deleting field value: $e');
      // Don't rethrow - it's okay if the value doesn't exist
    }
  }

  // ============= Item Completion Per Date Methods =============

  /// Set item completion status for a specific date (for Daily tracker lists)
  Future<void> setItemCompletionForDate({
    required String listId,
    required String itemId,
    required String ownerUserId,
    required String date, // Format: YYYY-MM-DD
    required bool completed,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(ownerUserId)
          .collection('lists')
          .doc(listId)
          .collection('items')
          .doc(itemId)
          .collection('completions')
          .doc(date)
          .set({
        'date': date,
        'completed': completed,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error setting item completion for date: $e');
      rethrow;
    }
  }

  /// Get item completion status for a specific date
  Future<bool> getItemCompletionForDate({
    required String listId,
    required String itemId,
    required String ownerUserId,
    required String date, // Format: YYYY-MM-DD
  }) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(ownerUserId)
          .collection('lists')
          .doc(listId)
          .collection('items')
          .doc(itemId)
          .collection('completions')
          .doc(date)
          .get();

      if (doc.exists) {
        return doc.data()?['completed'] == true;
      }
      return false; // Default to not completed
    } catch (e) {
      print('Error getting item completion for date: $e');
      return false;
    }
  }

  // --- Search Methods ---

  /// Search for users by partial email match
  /// Returns a list of {uid, email, displayName} for matching users
  Future<List<Map<String, dynamic>>> searchUsersByEmailPartial(
    String emailQuery,
  ) async {
    if (emailQuery.isEmpty) return [];

    try {
      final searchTerm = emailQuery.toLowerCase();
      final snapshot = await _firestore.collection('users').get();

      final results = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final email = (data['email'] as String?)?.toLowerCase() ?? '';
        final displayName = data['displayName'] as String? ?? 'Unknown';

        if (email.contains(searchTerm)) {
          results.add({
            'uid': doc.id,
            'email': data['email'],
            'displayName': displayName,
          });
        }
      }

      return results;
    } catch (e) {
      print('Error searching users by email: $e');
      return [];
    }
  }

  /// Search for lists shared with a specific collaborator email
  /// Returns a list of lists where this email has access
  Future<List<AppList>> searchSharedListsByCollaboratorEmail(
    String collaboratorEmail,
  ) async {
    try {
      // Query the shares collection for this email
      final snapshot = await _firestore
          .collection('shares')
          .where('sharedWithEmail', isEqualTo: collaboratorEmail)
          .get();

      final listIds = <String>{};
      for (final doc in snapshot.docs) {
        if (doc['listId'] != null) {
          listIds.add(doc['listId']);
        }
      }

      if (listIds.isEmpty) return [];

      // Get the list details for each shared list
      final lists = <AppList>[];
      for (final listId in listIds) {
        // We need to search across all users to find the list
        // This is a limitation of Firestore without cross-user queries
        // For now, we'll return empty - the client should handle this
      }

      return lists;
    } catch (e) {
      print('Error searching shared lists by collaborator: $e');
      return [];
    }
  }

  /// Get lists shared with the specified user ID
  /// Used for search filtering by collaborator
  Future<List<AppList>> getListsSharedWithUser(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('shares')
          .where('sharedWithUserId', isEqualTo: userId)
          .get();

      final lists = <AppList>[];
      final listIds = <String>{};

      for (final doc in snapshot.docs) {
        final listId = doc['listId'] as String?;
        if (listId != null) {
          listIds.add(listId);
        }
      }

      // Note: We don't have direct access to other users' lists in Firestore
      // This would require cross-user queries which Firestore doesn't support well
      // The app needs to maintain a separate shared lists collection or
      // the owner to maintain share information in their own lists

      return lists;
    } catch (e) {
      print('Error getting lists shared with user: $e');
      return [];
    }
  }

  /// Search for folders shared with the current user by email
  Future<List<Folder>> searchSharedFoldersByCollaboratorEmail(
    String collaboratorEmail,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('folder_shares')
          .where('sharedWithEmail', isEqualTo: collaboratorEmail)
          .get();

      const folders = <Folder>[];
      // Similar limitation as above
      return folders;
    } catch (e) {
      print('Error searching shared folders by collaborator: $e');
      return [];
    }
  }
}
