enum ItemFieldType {
  shortText,
  number,
  yesNo,
  date,
}
extension ItemFieldTypeExtension on ItemFieldType {
  String get displayName {
    switch (this) {
      case ItemFieldType.shortText:
        return 'Short Text';
      case ItemFieldType.number:
        return 'Number';
      case ItemFieldType.yesNo:
        return 'Yes/No';
      case ItemFieldType.date:
        return 'Date';
    }
  }
}