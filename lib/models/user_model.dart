class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, String uid) {
    return AppUser(
      uid: uid,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      photoUrl: map['photoUrl'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

enum ShareRole {
  viewer,
  editor,
  owner,
}

class ListShare {
  final String id;
  final String listId;
  final String ownerUserId;
  final String sharedWithUserId;
  final ShareRole role;
  final DateTime sharedAt;
  final String? sharedWithEmail;

  ListShare({
    required this.id,
    required this.listId,
    required this.ownerUserId,
    required this.sharedWithUserId,
    required this.role,
    required this.sharedAt,
    this.sharedWithEmail,
  });

  factory ListShare.fromMap(Map<String, dynamic> map, String id) {
    return ListShare(
      id: id,
      listId: map['listId'] ?? '',
      ownerUserId: map['ownerUserId'] ?? '',
      sharedWithUserId: map['sharedWithUserId'] ?? '',
      role: ShareRole.values.firstWhere(
        (e) => e.toString().split('.').last == map['role'],
        orElse: () => ShareRole.viewer,
      ),
      sharedAt: map['sharedAt'] != null
          ? DateTime.parse(map['sharedAt'])
          : DateTime.now(),
      sharedWithEmail: map['sharedWithEmail'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'listId': listId,
      'ownerUserId': ownerUserId,
      'sharedWithUserId': sharedWithUserId,
      'role': role.toString().split('.').last,
      'sharedAt': sharedAt.toIso8601String(),
      'sharedWithEmail': sharedWithEmail,
    };
  }
}
