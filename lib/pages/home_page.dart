import 'package:flutter/material.dart';
import '../models/folder_model.dart';
import '../models/list_model.dart';
import '../models/list_type.dart';
import 'list_detail_page.dart';
import '../widgets/create_list_dialog.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 📂 תיקיות דוגמה
  final List<Folder> folders = [
    Folder(id: '1', name: 'Personal'),
    Folder(id: '2', name: 'School'),
  ];

  // 📄 רשימות דוגמה
  final List<AppList> lists = [
    AppList(
      id: 'l1',
      title: 'Groceries',
      folderId: '1',
      type: ListType.regular,
    ),
    AppList(
      id: 'l2',
      title: 'Gym Plan',
      folderId: '1',
    ),
    AppList(
      id: 'l3',
      title: 'Homework',
      folderId: '2',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Lists'),
      ),

      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: folders.length,
        itemBuilder: (context, index) {
          final folder = folders[index];
          final folderLists =
              lists.where((list) => list.folderId == folder.id).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 📂 כותרת תיקייה
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  folder.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // 📄 רשימות בתיקייה
              ...folderLists.map((list) {
                return Card(
                  child: ListTile(
                    title: Text(list.title),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ListDetailPage(title: list.title),
                        ),
                      );
                    },
                  ),
                );
              }),

              const SizedBox(height: 16),
            ],
          );
        },
      ),

      // ➕ כפתור יצירת רשימה
     floatingActionButton: FloatingActionButton(
      child: const Icon(Icons.add),
      onPressed: () {
        showDialog(
          context: context,
          builder: (_) => CreateListDialog(
            folders: folders,
            onCreate: (newList) {
              setState(() {
                lists.add(newList);
          });
        },
      ),
    );
  },
),
    );
  }
}
