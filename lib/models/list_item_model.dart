import 'list_field_model.dart';
import 'list_field_value_model.dart';

class ListItemModel {
  final String id;
  String title;
  bool completed;

  /// הגדרת שדות
  List<ListField> fields;

  /// ערכי שדות
  List<ListFieldValue> fieldValues;

  ListItemModel({
    required this.id,
    required this.title,
    this.completed = false,
    List<ListField>? fields,
    List<ListFieldValue>? fieldValues,
  })  : fields = fields ?? [],
        fieldValues = fieldValues ?? [];
}
