import 'list_type.dart';

class AppList {
  final String id;
  final String title;
  final String folderId;
  final ListType type;

  AppList({
    required this.id,
    required this.title,
    required this.folderId,
    this.type = ListType.regular,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'folder_id': folderId,
      'type': type.toString().split('.').last,
    };
  }

  factory AppList.fromMap(Map<String, dynamic> map) {
    return AppList(
      id: map['id'],
      title: map['title'],
      folderId: map['folder_id'],
      type: ListType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => ListType.regular,
      ),
    );
  }
}

// import 'package:flutter/material.dart';

// enum ListType {
//   regular,
//   daily,
//   recurring,
// }

// class ListModel {
//   final String id;
//   final String title;
//   final ListType type;
//   final IconData icon;
//   final Color color;

//   ListModel({
//     required this.id,
//     required this.title,
//     required this.type,
//     required this.icon,
//     required this.color,
//   });
// }
