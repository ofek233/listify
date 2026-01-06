class ListFieldValue {
  final String fieldId;
  final String itemId;
  dynamic value;

  ListFieldValue({
    required this.fieldId,
    required this.itemId,
    this.value,
  });

  Map<String, dynamic> toMap() {
    return {
      'field_id': fieldId,
      'item_id': itemId,
      'value': value?.toString(),
    };
  }

  factory ListFieldValue.fromMap(Map<String, dynamic> map) {
    return ListFieldValue(
      fieldId: map['field_id'],
      itemId: map['item_id'],
      value: map['value'],
    );
  }
}
