import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models/folder_model.dart';
import 'models/list_model.dart';
import 'models/list_field_model.dart';
import 'models/list_item_model.dart';
import 'models/list_field_value_model.dart';
import 'models/item_field_type.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'listify_v2.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add item_completions table
      await db.execute('''
        CREATE TABLE item_completions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          item_id TEXT NOT NULL,
          date TEXT NOT NULL,
          completed INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (item_id) REFERENCES list_items (id) ON DELETE CASCADE,
          UNIQUE(item_id, date)
        )
      ''');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE folders (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');

    // Create lists table
    await db.execute('''
      CREATE TABLE lists (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        folder_id TEXT NOT NULL,
        type TEXT NOT NULL,
        role_model_item_id TEXT,
        FOREIGN KEY (folder_id) REFERENCES folders (id) ON DELETE CASCADE
      )
    ''');

    // Create list_fields table
    await db.execute('''
      CREATE TABLE list_fields (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        item_id TEXT NOT NULL,
        FOREIGN KEY (item_id) REFERENCES list_items (id) ON DELETE CASCADE
      )
    ''');

    // Create list_items table
    await db.execute('''
      CREATE TABLE list_items (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        list_id TEXT NOT NULL,
        "order" INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (list_id) REFERENCES lists (id) ON DELETE CASCADE
      )
    ''');

    // Create field_values table
    await db.execute('''
      CREATE TABLE field_values (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        field_id TEXT NOT NULL,
        item_id TEXT NOT NULL,
        value TEXT,
        FOREIGN KEY (field_id) REFERENCES list_fields (id) ON DELETE CASCADE,
        FOREIGN KEY (item_id) REFERENCES list_items (id) ON DELETE CASCADE,
        UNIQUE(field_id, item_id)
      )
    ''');

    // Create item_completions table for date-bound lists
    await db.execute('''
      CREATE TABLE item_completions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id TEXT NOT NULL,
        date TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (item_id) REFERENCES list_items (id) ON DELETE CASCADE,
        UNIQUE(item_id, date)
      )
    ''');
  }

  // Folder CRUD
  Future<List<Folder>> getFolders() async {
    final db = await database;
    final maps = await db.query('folders');
    return maps.map((map) => Folder.fromMap(map)).toList();
  }

  Future<void> insertFolder(Folder folder) async {
    final db = await database;
    await db.insert('folders', folder.toMap());
  }

  Future<void> updateFolder(Folder folder) async {
    final db = await database;
    await db.update('folders', folder.toMap(), where: 'id = ?', whereArgs: [folder.id]);
  }

  Future<void> deleteFolder(String id) async {
    final db = await database;
    await db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  // List CRUD
  Future<List<AppList>> getLists() async {
    final db = await database;
    final maps = await db.query('lists');
    return maps.map((map) => AppList.fromMap(map)).toList();
  }

  Future<AppList?> getList(String id) async {
    final db = await database;
    final maps = await db.query('lists', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return AppList.fromMap(maps.first);
  }

  Future<void> insertList(AppList list) async {
    final db = await database;
    await db.insert('lists', list.toMap());
  }

  Future<void> updateList(AppList list) async {
    final db = await database;
    await db.update('lists', list.toMap(), where: 'id = ?', whereArgs: [list.id]);
  }

  Future<void> deleteList(String id) async {
    final db = await database;
    await db.delete('lists', where: 'id = ?', whereArgs: [id]);
  }

  // Field CRUD
  Future<List<ListField>> getFields(String itemId) async {
    final db = await database;
    final maps = await db.query('list_fields', where: 'item_id = ?', whereArgs: [itemId]);
    return maps.map((map) => ListField.fromMap(map)).toList();
  }

  Future<void> insertField(ListField field) async {
    final db = await database;
    await db.insert('list_fields', field.toMap());
  }

  Future<void> updateField(ListField field) async {
    final db = await database;
    await db.update('list_fields', field.toMap(), where: 'id = ?', whereArgs: [field.id]);
  }

  Future<void> deleteField(String fieldId, String itemId) async {
    final db = await database;
    await db.delete('list_fields', where: 'id = ? AND item_id = ?', whereArgs: [fieldId, itemId]);
  }

  // Item CRUD
  Future<List<ListItemModel>> getItems(String listId) async {
    final db = await database;
    final maps = await db.query('list_items', where: 'list_id = ?', whereArgs: [listId], orderBy: '"order"');
    return maps.map((map) => ListItemModel.fromMap(map)).toList();
  }

  Future<ListItemModel?> getItem(String id) async {
    final db = await database;
    final maps = await db.query('list_items', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return ListItemModel.fromMap(maps.first);
  }

  Future<void> insertItem(ListItemModel item) async {
    final db = await database;
    final result = await db.rawQuery('SELECT MAX("order") as max_order FROM list_items WHERE list_id = ?', [item.listId]);
    final maxOrder = result.first['max_order'] as int? ?? -1;
    item.order = maxOrder + 1;
    await db.insert('list_items', item.toMap());
  }

  Future<void> updateItem(ListItemModel item) async {
    final db = await database;
    await db.update('list_items', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> deleteItem(String id) async {
    final db = await database;
    await db.delete('list_items', where: 'id = ?', whereArgs: [id]);
  }

  // Field Value CRUD
  Future<List<ListFieldValue>> getFieldValues(String itemId) async {
    final db = await database;
    final maps = await db.query('field_values', where: 'item_id = ?', whereArgs: [itemId]);
    return maps.map((map) => ListFieldValue.fromMap(map)).toList();
  }

  Future<void> insertOrUpdateFieldValue(ListFieldValue fieldValue) async {
    final db = await database;
    await db.insert(
      'field_values',
      fieldValue.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteFieldValue(String fieldId, String itemId) async {
    final db = await database;
    await db.delete('field_values', where: 'field_id = ? AND item_id = ?', whereArgs: [fieldId, itemId]);
  }

  // Helper to get items with fields and values
  Future<List<ListItemModel>> getItemsWithDetails(String listId) async {
    final items = await getItems(listId);

    for (final item in items) {
      item.fields = await getFields(item.id);
      item.fieldValues = await getFieldValues(item.id);
      for (final value in item.fieldValues) {
        final matching = item.fields.where((f) => f.id == value.fieldId);
        if (matching.isNotEmpty) {
          final field = matching.first;
          switch (field.type) {
            case ItemFieldType.shortText:
              value.value = value.value?.toString() ?? '';
              break;
            case ItemFieldType.number:
              value.value = int.tryParse(value.value?.toString() ?? '0') ?? 0;
              break;
            case ItemFieldType.yesNo:
              value.value = value.value?.toString().toLowerCase() == 'true';
              break;
            case ItemFieldType.date:
              value.value = DateTime.tryParse(value.value?.toString() ?? '');
              break;
            default:
              break;
          }
        }
      }
    }

    return items;
  }

  // Copy items
  Future<void> copyItems(List<ListItemModel> items, String targetListId) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final item in items) {
        final newItemId = '${DateTime.now().millisecondsSinceEpoch}_${item.id}';
        final newItem = ListItemModel(
          id: newItemId,
          title: item.title,
          listId: targetListId,
          completed: item.completed,
        );
        await txn.insert('list_items', newItem.toMap());

        // Copy field values
        for (final fieldValue in item.fieldValues) {
          final newFieldValue = ListFieldValue(
            fieldId: fieldValue.fieldId,
            itemId: newItemId,
            value: fieldValue.value,
          );
          await txn.insert('field_values', newFieldValue.toMap());
        }
      }
    });
  }

  // Apply role model fields to list
  Future<void> applyRoleModel(String listId, List<String> fieldIds) async {
    final db = await database;
    final items = await getItems(listId);
    final existingFields = await getFields(listId);

    // Ensure all items have these fields
    for (final item in items) {
      for (final fieldId in fieldIds) {
        final existingValue = item.fieldValues.where((v) => v.fieldId == fieldId);
        if (existingValue.isEmpty) {
          final fieldValue = ListFieldValue(
            fieldId: fieldId,
            itemId: item.id,
          );
          await insertOrUpdateFieldValue(fieldValue);
        }
      }
    }
  }

  // Apply role model fields to all items in the list
  Future<void> applyRoleModelFields(String listId, String roleItemId) async {
    final allItems = await getItemsWithDetails(listId);
    ListItemModel? roleItem;
    try {
      roleItem = allItems.firstWhere((i) => i.id == roleItemId);
    } catch (e) {
      roleItem = null;
    }
    if (roleItem == null) return;
    for (final item in allItems.where((i) => i.id != roleItemId)) {
      for (final field in roleItem.fields) {
        final existing = item.fields.where((f) => f.name == field.name && f.type == field.type);
        if (existing.isEmpty) {
          final newField = field.copyWith(id: DateTime.now().millisecondsSinceEpoch.toString(), itemId: item.id);
          await insertField(newField);
          await insertOrUpdateFieldValue(ListFieldValue(fieldId: newField.id, itemId: item.id, value: null));
        }
      }
    }
  }

  Future<void> updateItemsOrder(String listId, String roleItemId) async {
    final db = await database;
    await db.rawUpdate('UPDATE list_items SET "order" = "order" + 1 WHERE list_id = ? AND id != ?', [listId, roleItemId]);
  }

  // Item completion per date methods
  Future<bool> getItemCompletionForDate(String itemId, DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().split('T')[0]; // YYYY-MM-DD format
    final maps = await db.query(
      'item_completions',
      where: 'item_id = ? AND date = ?',
      whereArgs: [itemId, dateStr],
    );
    if (maps.isNotEmpty) {
      return maps.first['completed'] == 1;
    }
    return false; // Default to false if no record
  }

  Future<void> setItemCompletionForDate(String itemId, DateTime date, bool completed) async {
    final db = await database;
    final dateStr = date.toIso8601String().split('T')[0]; // YYYY-MM-DD format
    await db.insert(
      'item_completions',
      {
        'item_id': itemId,
        'date': dateStr,
        'completed': completed ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}