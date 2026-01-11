import 'list_field_model.dart';
import 'list_field_value_model.dart';

class ListItemModel {
  final String id;
  String title;
  bool completed;
  final String listId;
  int order;

  /// הגדרת שדות
  List<ListField> fields;

  /// ערכי שדות
  List<ListFieldValue> fieldValues;

  ListItemModel({
    required this.id,
    required this.title,
    required this.listId,
    this.completed = false,
    this.order = 0,
    List<ListField>? fields,
    List<ListFieldValue>? fieldValues,
  })  : fields = fields ?? [],
        fieldValues = fieldValues ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'completed': completed ? 1 : 0,
      'list_id': listId,
      'order': order,
    };
  }

  ListItemModel copyWith({
    String? id,
    String? title,
    bool? completed,
    String? listId,
    int? order,
    List<ListField>? fields,
    List<ListFieldValue>? fieldValues,
  }) {
    return ListItemModel(
      id: id ?? this.id,
      title: title ?? this.title,
      listId: listId ?? this.listId,
      completed: completed ?? this.completed,
      order: order ?? this.order,
      fields: fields ?? this.fields,
      fieldValues: fieldValues ?? this.fieldValues,
    );
  }

  factory ListItemModel.fromMap(Map<String, dynamic> map) {
    return ListItemModel(
      id: map['id'],
      title: map['title'],
      completed: map['completed'] == 1,
      listId: map['list_id'],
      order: map['order'] ?? 0,
    );
  }
}
