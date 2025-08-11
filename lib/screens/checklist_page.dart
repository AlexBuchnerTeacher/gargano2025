import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class ChecklistPage extends StatefulWidget {
  const ChecklistPage({super.key});

  @override
  State<ChecklistPage> createState() => _ChecklistPageState();
}

class _ChecklistPageState extends State<ChecklistPage> {
  // ---- Reise-Kontext / Pfade ----
  final String _tripId = 'default'; // TODO: später dynamisch setzen
  late final String _uid;
  late final CollectionReference<Map<String, dynamic>> _catCol;
  late final CollectionReference<Map<String, dynamic>> _itemCol;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Kein Benutzer eingeloggt.');
    }
    _uid = user.uid;

    final base = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('trips')
        .doc(_tripId);

    _catCol = base.collection('checklist_categories');
    _itemCol = base.collection('checklist_items');

    _seedIfEmpty();
  }

  /// Seeden, falls noch keine Kategorien vorhanden sind
  Future<void> _seedIfEmpty() async {
    final cats = await _catCol.limit(1).get();
    if (cats.size > 0) return;
    await _seedFromDefaults(); // neu: zuerst Firestore, dann Asset-Fallback
  }

  /// Seedet aus Firestore-Config (Fallback: Asset)
  Future<void> _seedFromDefaults() async {
    try {
      final used = await _seedFromFirestore();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Packliste aus ${used ? "Cloud" : "Asset"} geladen.')),
      );
    } catch (e) {
      try {
        await _seedFromAssets();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Packliste aus Asset geladen.')),
        );
      } catch (e2) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Seed fehlgeschlagen: $e2')),
        );
      }
    }
  }

  /// Liest Defaults aus Firestore und seedet sie in die User-Collections.
  /// Erwartet das Dokument: config/checklist_default
  ///
  /// Unterstützte Formate:
  ///   A) { itemsByCategory: { "Küche": ["Pfanne","Öl"], ... }, version: n, updatedAt: ts }
  ///   B) { "Küche": ["Pfanne","Öl"], "Dokumente": ["Pass",...], ... }  (reines Map wie Asset)
  ///
  /// Rückgabewert: true, wenn Cloud verwendet wurde; false, wenn auf Asset zurückgefallen wird.
  Future<bool> _seedFromFirestore() async {
    final doc = await FirebaseFirestore.instance
        .collection('config')
        .doc('checklist_default')
        .get();

    if (!doc.exists) {
      await _seedFromAssets();
      return false;
    }

    final data = doc.data()!;
    final dynamic raw = data['itemsByCategory'] ?? data['items'] ?? data;

    if (raw is! Map) {
      await _seedFromAssets();
      return false;
    }

    final Map<String, dynamic> categoriesMap =
        raw.map((k, v) => MapEntry(k.toString(), v));

    final batch = FirebaseFirestore.instance.batch();

    int catIdx = 0;
    for (final entry in categoriesMap.entries) {
      final catName = entry.key;
      final dynamic list = entry.value;

      if (list is! List) continue;

      final catRef = _catCol.doc();
      batch.set(catRef, {
        'name': catName,
        'idx': catIdx++,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      int itemIdx = 0;
      for (final item in list) {
        final title = item?.toString().trim();
        if (title == null || title.isEmpty) continue;

        final itemRef = _itemCol.doc();
        batch.set(itemRef, {
          'categoryId': catRef.id,
          'title': title,
          'checked': false,
          'idx': itemIdx++,
          'qty': null,
          'note': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
    return true;
  }

  /// Seedet aus assets/checklist.json (altes Default-Format)
  Future<void> _seedFromAssets() async {
    final jsonString = await rootBundle.loadString('assets/checklist.json');
    final Map<String, dynamic> jsonData = jsonDecode(jsonString);

    final batch = FirebaseFirestore.instance.batch();

    int catIdx = 0;
    for (final entry in jsonData.entries) {
      final catName = entry.key.toString();
      final catRef = _catCol.doc();
      batch.set(catRef, {
        'name': catName,
        'idx': catIdx++,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final List items = (entry.value as List);
      int itemIdx = 0;
      for (final title in items) {
        final itemRef = _itemCol.doc();
        batch.set(itemRef, {
          'categoryId': catRef.id,
          'title': title.toString(),
          'checked': false,
          'idx': itemIdx++,
          'qty': null,
          'note': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
  }

  /// Eintrag hinzufügen
  Future<void> _addItem(String categoryId) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Neuen Eintrag hinzufügen'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Bezeichnung'),
          autofocus: true,
          onSubmitted: (_) => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;

              final last = await _itemCol
                  .where('categoryId', isEqualTo: categoryId)
                  .orderBy('idx', descending: true)
                  .limit(1)
                  .get();

              final nextIdx = last.docs.isEmpty
                  ? 0
                  : ((last.docs.first.data()['idx'] as num?)?.toInt() ?? 0) + 1;

              await _itemCol.add({
                'categoryId': categoryId,
                'title': controller.text.trim(),
                'checked': false,
                'idx': nextIdx,
                'qty': null,
                'note': null,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
  }

  /// Kategorie hinzufügen
  Future<void> _addCategory() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Neue Kategorie hinzufügen'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Kategoriename'),
          autofocus: true,
          onSubmitted: (_) => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;

              final last =
                  await _catCol.orderBy('idx', descending: true).limit(1).get();
              final nextIdx = last.docs.isEmpty
                  ? 0
                  : ((last.docs.first.data()['idx'] as num?)?.toInt() ?? 0) + 1;

              await _catCol.add({
                'name': controller.text.trim(),
                'idx': nextIdx,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
  }

  /// Kategorie umbenennen
  Future<void> _renameCategory(String catId, String currentName) async {
    final controller = TextEditingController(text: currentName);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kategorie umbenennen'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Neuer Name'),
          autofocus: true,
          onSubmitted: (_) => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              await _catCol.doc(catId).set({
                'name': newName,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  /// Eintrag löschen
  Future<void> _deleteItem(String itemId) async {
    await _itemCol.doc(itemId).delete();
  }

  /// Kategorie löschen (inkl. aller Items)
  Future<void> _deleteCategory(String catId, String catName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kategorie löschen?'),
        content: Text(
          '„$catName“ und alle enthaltenen Einträge werden dauerhaft gelöscht.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      // Alle Items der Kategorie löschen
      const pageSize = 300;
      while (true) {
        final snap = await _itemCol
            .where('categoryId', isEqualTo: catId)
            .limit(pageSize)
            .get();
        if (snap.docs.isEmpty) break;
        final batch = FirebaseFirestore.instance.batch();
        for (final d in snap.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
        if (snap.docs.length < pageSize) break;
      }
      // Kategorie löschen
      await _catCol.doc(catId).delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('„$catName“ gelöscht.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Löschen fehlgeschlagen: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Fortschritt pro Kategorie berechnen
  double _progressForCategory(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> itemDocs) {
    if (itemDocs.isEmpty) return 0;
    int checked = 0;
    for (final d in itemDocs) {
      final c = d.data()['checked'] == true;
      if (c) checked++;
    }
    return checked / itemDocs.length;
  }

  /// Gesamte Collection löschen (wird beim Reset genutzt)
  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> col, {
    int batchSize = 300,
  }) async {
    Query<Map<String, dynamic>> query = col.limit(batchSize);
    while (true) {
      final snap = await query.get();
      if (snap.docs.isEmpty) break;
      final batch = FirebaseFirestore.instance.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      if (snap.docs.length < batchSize) break;
    }
  }

  /// Zurücksetzen mit Cloud-Defaults (Fallback: Asset)
  Future<void> _confirmAndReset() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Packliste zurücksetzen?'),
        content: const Text(
          'Alle Kategorien und Einträge dieser Reise werden gelöscht und aus der Vorlage neu erstellt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Zurücksetzen'),
          ),
        ],
      ),
    );

    if (result != true) return;

    setState(() => _busy = true);
    try {
      await _deleteCollection(_itemCol); // erst Items löschen
      await _deleteCollection(_catCol); // dann Kategorien
      await _seedFromDefaults(); // neu: Cloud → Asset
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Zurücksetzen fehlgeschlagen: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AbsorbPointer(
      absorbing: _busy,
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: const Text('Packliste'),
              actions: [
                IconButton(
                  onPressed: _addCategory,
                  icon: const Icon(Icons.add),
                  tooltip: 'Neue Kategorie',
                ),
                IconButton(
                  onPressed: _confirmAndReset,
                  icon: const Icon(Icons.restart_alt),
                  tooltip: 'Zurücksetzen',
                ),
              ],
            ),
            body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _catCol.orderBy('idx').snapshots(),
              builder: (context, catSnap) {
                if (catSnap.connectionState == ConnectionState.waiting &&
                    !catSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (catSnap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'Fehler beim Laden der Kategorien:\n${catSnap.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final cats = catSnap.data?.docs ?? [];
                if (cats.isEmpty) {
                  return const Center(
                    child: Text('Noch keine Kategorien. Füge oben eine hinzu.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: cats.length,
                  itemBuilder: (context, index) {
                    final catDoc = cats[index];
                    final catId = catDoc.id;
                    final catName =
                        catDoc.data()['name'] as String? ?? 'Kategorie';

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _itemCol
                          .where('categoryId', isEqualTo: catId)
                          .orderBy('idx')
                          .snapshots(),
                      builder: (context, itemSnap) {
                        if (itemSnap.connectionState ==
                                ConnectionState.waiting &&
                            !itemSnap.hasData) {
                          return const Card(
                            margin: EdgeInsets.symmetric(vertical: 8),
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          );
                        }
                        if (itemSnap.hasError) {
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                'Fehler beim Laden von "$catName":\n${itemSnap.error}',
                              ),
                            ),
                          );
                        }

                        final items = itemSnap.data?.docs ?? [];
                        final progress = _progressForCategory(items);

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: cs.outlineVariant,
                            ),
                          ),
                          color: cs.surface, // M3 surface
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Titel + Aktionen + Fortschritt in Zeile
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        catName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                    // Prozentanzeige
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Text(
                                        "${(progress * 100).toStringAsFixed(0)}%",
                                        style:
                                            Theme.of(context).textTheme.labelLarge,
                                      ),
                                    ),
                                    // Kontextmenü
                                    PopupMenuButton<String>(
                                      tooltip: 'Optionen',
                                      onSelected: (value) {
                                        switch (value) {
                                          case 'rename':
                                            _renameCategory(catId, catName);
                                            break;
                                          case 'delete':
                                            _deleteCategory(catId, catName);
                                            break;
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'rename',
                                          child: ListTile(
                                            leading: Icon(Icons.edit),
                                            title: Text('Umbenennen'),
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: ListTile(
                                            leading: Icon(Icons.delete_outline),
                                            title: Text('Kategorie löschen'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // Fortschrittsbalken (M3)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor:
                                        cs.surfaceContainerHighest,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(cs.primary),
                                    minHeight: 8,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Items
                                ...items.map((doc) {
                                  final data = doc.data();
                                  final title = data['title'] as String? ?? '';
                                  final checked = data['checked'] == true;

                                  return Dismissible(
                                    key: ValueKey(doc.id),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      color: cs.error,
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      child: const Icon(Icons.delete,
                                          color: Colors.white),
                                    ),
                                    onDismissed: (_) => _deleteItem(doc.id),
                                    child: CheckboxListTile(
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      title: Text(title),
                                      value: checked,
                                      onChanged: (val) {
                                        _itemCol.doc(doc.id).set({
                                          'checked': val == true,
                                          'updatedAt':
                                              FieldValue.serverTimestamp(),
                                        }, SetOptions(merge: true));
                                      },
                                    ),
                                  );
                                }),

                                // Eintrag hinzufügen
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () => _addItem(catId),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Eintrag hinzufügen'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          if (_busy)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.08),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
