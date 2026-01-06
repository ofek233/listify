import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'database_helper.dart';
import 'models/folder_model.dart';
import 'models/list_model.dart';
import 'models/list_type.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  try {
    await _initializeDatabase();
  } catch (e) {
    print('Error initializing database: $e');
  }
  runApp(const ListifyApp());
}

Future<void> _initializeDatabase() async {
  final dbHelper = DatabaseHelper();
  final folders = await dbHelper.getFolders();
  if (folders.isEmpty) {
    // Create default folders
    final personalFolder = Folder(
      id: '1',
      name: 'Personal',
    );
    final schoolFolder = Folder(
      id: '2',
      name: 'School',
    );
    await dbHelper.insertFolder(personalFolder);
    await dbHelper.insertFolder(schoolFolder);

    // Create default lists
    final groceriesList = AppList(
      id: 'l1',
      title: 'Groceries',
      folderId: '1',
      type: ListType.regular,
    );
    final gymList = AppList(
      id: 'l2',
      title: 'Gym Plan',
      folderId: '1',
      type: ListType.regular,
    );
    final homeworkList = AppList(
      id: 'l3',
      title: 'Homework',
      folderId: '2',
      type: ListType.regular,
    );
    await dbHelper.insertList(groceriesList);
    await dbHelper.insertList(gymList);
    await dbHelper.insertList(homeworkList);
  }
}

class ListifyApp extends StatelessWidget {
  const ListifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Listify',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
