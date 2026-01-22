import 'package:flutter/material.dart';
import '../models/list_model.dart';
import '../models/list_type.dart';

class RecurringTimerSetupDialog extends StatefulWidget {
  final String listTitle;
  final Function(AppList) onCreate;

  const RecurringTimerSetupDialog({
    super.key,
    required this.listTitle,
    required this.onCreate,
  });

  @override
  State<RecurringTimerSetupDialog> createState() => _RecurringTimerSetupDialogState();
}

class _RecurringTimerSetupDialogState extends State<RecurringTimerSetupDialog> {
  DateTime? selectedDueDate;
  bool isRepeating = false;
  RepeatInterval repeatInterval = RepeatInterval.day;
  bool saveItemsBetweenCycles = false;

  void _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)), // 2 years ahead
    );
    if (picked != null) {
      setState(() {
        selectedDueDate = picked;
      });
    }
  }

  void _createRecurringTimer() {
    if (selectedDueDate == null) return;

    final list = AppList(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: widget.listTitle,
      folderId: '', // This will be set by the parent dialog
      type: ListType.recurring,
      dueDate: selectedDueDate,
      isRepeating: isRepeating,
      repeatInterval: isRepeating ? repeatInterval : null,
      saveItemsBetweenCycles: isRepeating ? saveItemsBetweenCycles : null,
    );

    widget.onCreate(list);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Setup Recurring Timer: ${widget.listTitle}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Due Date Selection
            const Text(
              'Due Date',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    selectedDueDate != null
                        ? '${selectedDueDate!.month}/${selectedDueDate!.day}/${selectedDueDate!.year}'
                        : 'Select due date',
                    style: TextStyle(
                      color: selectedDueDate != null ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _selectDueDate,
                ),
              ],
            ),
            const Divider(),

            // Repeating Option
            Row(
              children: [
                const Text(
                  'Repeat',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Switch(
                  value: isRepeating,
                  onChanged: (value) {
                    setState(() {
                      isRepeating = value;
                    });
                  },
                ),
              ],
            ),

            if (isRepeating) ...[
              const SizedBox(height: 16),
              const Text(
                'Repeat every',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<RepeatInterval>(
                initialValue: repeatInterval,
                items: [
                  DropdownMenuItem(
                    value: RepeatInterval.day,
                    child: const Text('Day'),
                  ),
                  DropdownMenuItem(
                    value: RepeatInterval.week,
                    child: const Text('Week'),
                  ),
                  DropdownMenuItem(
                    value: RepeatInterval.month,
                    child: const Text('Month'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => repeatInterval = value);
                  }
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Save items between cycles',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Switch(
                    value: saveItemsBetweenCycles,
                    onChanged: (value) {
                      setState(() {
                        saveItemsBetweenCycles = value;
                      });
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: selectedDueDate != null ? _createRecurringTimer : null,
          child: const Text('Create'),
        ),
      ],
    );
  }
}