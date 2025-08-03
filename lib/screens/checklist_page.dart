import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChecklistPage extends StatefulWidget {
  const ChecklistPage({super.key});

  @override
  State<ChecklistPage> createState() => _ChecklistPageState();
}

class _ChecklistPageState extends State<ChecklistPage> {
  final List<String> checklistItems = [
    'Snacks griffbereit',
    'Wasserflaschen kalt',
    'Powerbank & Ladekabel',
    'Playlist / Hörbuch offline',
    'Vignette + Mautgeld',
    'Sonnenbrillen',
    'Müllbeutel',
    'Notfallapotheke',
  ];

  late List<bool> checkedState = List.filled(8, false);

  @override
  void initState() {
    super.initState();
    _loadChecklistState();
  }

  Future<void> _loadChecklistState() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('checklist') ?? [];
    if (saved.isNotEmpty && saved.length == checklistItems.length) {
      setState(() {
        checkedState = saved.map((e) => e == 'true').toList();
      });
    }
  }

  Future<void> _saveChecklistState() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList('checklist', checkedState.map((e) => e.toString()).toList());
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: checklistItems.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: CheckboxListTile(
            value: checkedState[index],
            onChanged: (val) {
              setState(() {
                checkedState[index] = val ?? false;
                _saveChecklistState();
              });
            },
            title: Text(checklistItems[index]),
          ),
        );
      },
    );
  }
}
