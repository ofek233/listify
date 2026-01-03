import 'package:flutter/material.dart';
import '../models/list_item_model.dart';
import '../widgets/item_edit_dialog.dart';

class ListDetailPage extends StatefulWidget {
  final String title;

  const ListDetailPage({super.key, required this.title});

  @override
  State<ListDetailPage> createState() => _ListDetailPageState();
}

class _ListDetailPageState extends State<ListDetailPage> {
  final List<ListItem> items = [];

  void _addItem(String name) {
    setState(() {
      items.add(
        ListItem(
          id: DateTime.now().toString(),
          title: name,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (_, index) {
          final item = items[index];

          return ListTile(
            leading: Checkbox(
              value: item.completed,
              onChanged: (val) {
                setState(() => item.completed = val ?? false);
              },
            ),
            title: Text(item.title),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => ItemEditDialog(
                  item: item,
                  onUpdate: () => setState(() {}),
                ),
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) {
              final controller = TextEditingController();
              return AlertDialog(
                title: const Text('Add Item'),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  decoration:
                      const InputDecoration(labelText: 'Item name'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (controller.text.trim().isNotEmpty) {
                        _addItem(controller.text.trim());
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Add'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
