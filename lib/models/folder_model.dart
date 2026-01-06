class Folder {
  final String id;
  final String name;

  Folder({
    required this.id,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'],
      name: map['name'],
    );
  }
}

// import 'list_model.dart';

// class FolderModel {
//   final String id;
//   final String title;
//   final List<ListModel> lists;
//   bool isExpanded;

//   FolderModel({
//     required this.id,
//     required this.title,
//     required this.lists,
//     this.isExpanded = true,
//   });
// }
