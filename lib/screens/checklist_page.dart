import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ChecklistPage extends StatefulWidget {
  const ChecklistPage({super.key});

  @override
  State<ChecklistPage> createState() => _ChecklistPageState();
}

class _ChecklistPageState extends State<ChecklistPage> {
  Map<String, List<Map<String, dynamic>>> categories = {};
  List<bool> expandedStates = [];

  @override
  void initState() {
    super.initState();
    _loadChecklist();
  }

  /// Lade gespeicherte Daten oder JSON aus Assets
  Future<void> _loadChecklist() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString('checklist');

    if (savedData != null) {
      categories = Map<String, List<Map<String, dynamic>>>.from(
        jsonDecode(savedData).map((key, value) => MapEntry(
              key,
              List<Map<String, dynamic>>.from(
                  value.map((item) => Map<String, dynamic>.from(item))),
            )),
      );
    } else {
      final jsonString = await rootBundle.loadString('assets/checklist.json');
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);

      categories = jsonData.map((key, value) {
        final List<String> items = List<String>.from(value);
        return MapEntry(
          key,
          items.map((title) => {'title': title, 'checked': false}).toList(),
        );
      });
    }

    setState(() {
      expandedStates = List.generate(categories.length, (_) => true);
    });
  }

  /// Speichere aktuelle Daten
  Future<void> _saveChecklist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('checklist', jsonEncode(categories));
  }

  /// Fortschritt pro Kategorie berechnen
  double _getProgress(String category) {
    final items = categories[category]!;
    if (items.isEmpty) return 0;
    final checkedCount = items.where((item) => item['checked'] == true).length;
    return checkedCount / items.length;
  }

  /// Eintrag hinzufügen
  void _addItem(String category) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Neuen Eintrag hinzufügen'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Bezeichnung'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  categories[category]!
                      .add({'title': controller.text, 'checked': false});
                });
                _saveChecklist();
                Navigator.pop(context);
              }
            },
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
  }

  /// Kategorie hinzufügen
  void _addCategory() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Neue Kategorie hinzufügen'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Kategoriename'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  categories[controller.text] = [];
                  expandedStates.add(true);
                });
                _saveChecklist();
                Navigator.pop(context);
              }
            },
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
  }

  /// Eintrag löschen
  void _deleteItem(String category, int index) {
    setState(() {
      categories[category]!.removeAt(index);
    });
    _saveChecklist();
  }

  @override
  Widget build(BuildContext context) {
    final categoryKeys = categories.keys.toList();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Packliste'),
        actions: [
          IconButton(
            onPressed: _addCategory,
            icon: const Icon(Icons.add),
            tooltip: 'Neue Kategorie',
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: categoryKeys.length,
        itemBuilder: (context, index) {
          final category = categoryKeys[index];
          final progress = _getProgress(category);
          final items = categories[category]!;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titel + Fortschrittsbalken
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        category,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "${(progress * 100).toStringAsFixed(0)}%",
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Einträge
                  ...items.asMap().entries.map((entry) {
                    final itemIndex = entry.key;
                    final item = entry.value;
                    return Dismissible(
                      key: UniqueKey(),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: colorScheme.error,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _deleteItem(category, itemIndex),
                      child: CheckboxListTile(
                        title: Text(item['title']),
                        value: item['checked'],
                        onChanged: (val) {
                          setState(() {
                            item['checked'] = val;
                          });
                          _saveChecklist();
                        },
                      ),
                    );
                  }),

                  // Button Eintrag hinzufügen
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _addItem(category),
                      icon: const Icon(Icons.add),
                      label: const Text('Eintrag hinzufügen'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
