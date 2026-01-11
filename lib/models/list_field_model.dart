import 'item_field_type.dart';

class ListField {
  final String id;
  String name;
  ItemFieldType type;
  final String itemId;

  ListField({
    required this.id,
    required this.name,
    required this.type,
    required this.itemId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.toString().split('.').last,
      'item_id': itemId,
    };
  }

  ListField copyWith({
    String? id,
    String? name,
    ItemFieldType? type,
    String? itemId,
  }) {
    return ListField(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      itemId: itemId ?? this.itemId,
    );
  }

  factory ListField.fromMap(Map<String, dynamic> map) {
    return ListField(
      id: map['id'],
      name: map['name'],
      type: ItemFieldType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
      ),
      itemId: map['item_id'],
    );
  }
}
