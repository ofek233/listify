import 'item_field_model.dart';

class ListItem {
  final String id;
  String title;
  bool completed;
  final List<ItemField> fields;

  ListItem({
    required this.id,
    required this.title,
    this.completed = false,
    List<ItemField>? fields,
  }) : fields = fields ?? [];
}
