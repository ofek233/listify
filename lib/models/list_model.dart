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
