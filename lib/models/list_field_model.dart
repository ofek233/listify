import 'item_field_type.dart';

class ListField {
  final String id;
  String name;
  ItemFieldType type;
  final String listId;

  ListField({
    required this.id,
    required this.name,
    required this.type,
    required this.listId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.toString().split('.').last,
      'list_id': listId,
    };
  }

  factory ListField.fromMap(Map<String, dynamic> map) {
    return ListField(
      id: map['id'],
      name: map['name'],
      type: ItemFieldType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
      ),
      listId: map['list_id'],
    );
  }
}
