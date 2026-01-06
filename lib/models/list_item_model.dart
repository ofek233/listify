import 'list_field_model.dart';
import 'list_field_value_model.dart';

class ListItemModel {
  final String id;
  String title;
  bool completed;
  final String listId;

  /// הגדרת שדות
  List<ListField> fields;

  /// ערכי שדות
  List<ListFieldValue> fieldValues;

  ListItemModel({
    required this.id,
    required this.title,
    required this.listId,
    this.completed = false,
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
    };
  }

  factory ListItemModel.fromMap(Map<String, dynamic> map) {
    return ListItemModel(
      id: map['id'],
      title: map['title'],
      completed: map['completed'] == 1,
      listId: map['list_id'],
    );
  }
}
