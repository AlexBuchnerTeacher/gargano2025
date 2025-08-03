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
      // Daten aus SharedPreferences laden
      categories = Map<String, List<Map<String, dynamic>>>.from(
        jsonDecode(savedData).map((key, value) => MapEntry(
              key,
              List<Map<String, dynamic>>.from(
                  value.map((item) => Map<String, dynamic>.from(item))),
            )),
      );
    } else {
      // JSON-Datei laden
      final jsonString = await rootBundle.loadString('assets/checklist.json');
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);

      // In unsere Struktur mit checked-Status umwandeln
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
    TextEditingController controller = TextEditingController();
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
          ElevatedButton(
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
    TextEditingController controller = TextEditingController();
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
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  categories[controller.text] = [];
                  expandedStates.add(true); // direkt offen
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
      body: SingleChildScrollView(
        child: ExpansionPanelList(
          expansionCallback: (int index, bool isExpanded) {
            setState(() {
              expandedStates[index] = !isExpanded;
            });
          },
          children: categoryKeys.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            final items = categories[category]!;

            return ExpansionPanel(
              isExpanded: expandedStates[index],
              headerBuilder: (context, isExpanded) {
                return ListTile(
                  title: Text(
                    category,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: LinearProgressIndicator(
                    value: _getProgress(category),
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                );
              },
              body: Column(
                children: [
                  ...items.asMap().entries.map((entry) {
                    final itemIndex = entry.key;
                    final item = entry.value;
                    return Dismissible(
                      key: UniqueKey(),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
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
                  TextButton.icon(
                    onPressed: () => _addItem(category),
                    icon: const Icon(Icons.add),
                    label: const Text('Eintrag hinzufügen'),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
