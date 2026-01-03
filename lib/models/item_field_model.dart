import 'item_field_type.dart';

class ItemField {
  final String id;
  final String name;
  final ItemFieldType type;
  dynamic value;

  ItemField({
    required this.id,
    required this.name,
    required this.type,
    this.value,
  });
}
