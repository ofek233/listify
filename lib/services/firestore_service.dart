import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/list_model.dart';
import '../models/list_type.dart';
import '../models/folder_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      );
    }).toList();
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
        });
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
    final shareId = _firestore.collection('shares').doc().id;

    await _firestore.collection('shares').doc(shareId).set({
      'listId': listId,
      'ownerUserId': ownerUserId,
      'sharedWithUserId': targetUserId,
      'sharedWithEmail': targetEmail,
      'role': role.toString().split('.').last,
      'sharedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<List<ListShare>> getSharedListsForUser(String userId) async {
    final snapshot = await _firestore
        .collection('shares')
        .where('sharedWithUserId', isEqualTo: userId)
        .get();

    return snapshot.docs
        .map((doc) => ListShare.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<ListShare>> getListShares(String listId) async {
    final snapshot = await _firestore
        .collection('shares')
        .where('listId', isEqualTo: listId)
        .get();

    return snapshot.docs
        .map((doc) => ListShare.fromMap(doc.data(), doc.id))
        .toList();
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
}
