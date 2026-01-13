import 'list_type.dart';

enum RepeatInterval {
  day,
  week,
  month,
}

class AppList {
  final String id;
  final String title;
  final String folderId;
  final ListType type;
  final String? roleModelItemId;
  final DateTime? dueDate;
  final bool? isRepeating;
  final RepeatInterval? repeatInterval;
  final bool? saveItemsBetweenCycles;

  AppList({
    required this.id,
    required this.title,
    required this.folderId,
    this.type = ListType.regular,
    this.roleModelItemId,
    this.dueDate,
    this.isRepeating,
    this.repeatInterval,
    this.saveItemsBetweenCycles,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'folder_id': folderId,
      'type': type.toString().split('.').last,
      'role_model_item_id': roleModelItemId,
      'due_date': dueDate?.toIso8601String(),
      'is_repeating': isRepeating == true ? 1 : 0,
      'repeat_interval': repeatInterval?.toString().split('.').last,
      'save_items_between_cycles': saveItemsBetweenCycles == true ? 1 : 0,
    };
  }

  AppList copyWith({
    String? id,
    String? title,
    String? folderId,
    ListType? type,
    String? roleModelItemId,
    DateTime? dueDate,
    bool? isRepeating,
    RepeatInterval? repeatInterval,
    bool? saveItemsBetweenCycles,
  }) {
    return AppList(
      id: id ?? this.id,
      title: title ?? this.title,
      folderId: folderId ?? this.folderId,
      type: type ?? this.type,
      roleModelItemId: roleModelItemId ?? this.roleModelItemId,
      dueDate: dueDate ?? this.dueDate,
      isRepeating: isRepeating ?? this.isRepeating,
      repeatInterval: repeatInterval ?? this.repeatInterval,
      saveItemsBetweenCycles: saveItemsBetweenCycles ?? this.saveItemsBetweenCycles,
    );
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
      roleModelItemId: map['role_model_item_id'],
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date']) : null,
      isRepeating: map['is_repeating'] == 1,
      repeatInterval: map['repeat_interval'] != null
          ? RepeatInterval.values.firstWhere(
              (e) => e.toString().split('.').last == map['repeat_interval'],
              orElse: () => RepeatInterval.day,
            )
          : null,
      saveItemsBetweenCycles: map['save_items_between_cycles'] == 1,
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
