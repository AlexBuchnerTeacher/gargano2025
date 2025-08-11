import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';

class InfosTab extends StatefulWidget {
  const InfosTab({super.key});

  @override
  State<InfosTab> createState() => _InfosTabState();
}

class _InfosTabState extends State<InfosTab> {
  final String _tripId = 'default'; // TODO: später dynamisch setzen
  late final String _uid;
  late final CollectionReference<Map<String, dynamic>> _infoCol;

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

    _infoCol = base.collection('infos');
    _seedIfEmpty();
  }

  // ------------------- Seed-Logik -------------------
  Future<void> _seedIfEmpty() async {
    final infos = await _infoCol.limit(1).get();
    if (infos.size > 0) return;
    await _seedFromDefaults();
  }

  Future<void> _setBusy(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetAndReseed() async {
    await _setBusy(() async {
      // alle Infos löschen (paging)
      const page = 300;
      while (true) {
        final snap = await _infoCol.limit(page).get();
        if (snap.docs.isEmpty) break;
        final b = FirebaseFirestore.instance.batch();
        for (final d in snap.docs) {
          b.delete(d.reference);
        }
        await b.commit();
        if (snap.docs.length < page) break;
      }
      await _seedFromDefaults();
    });
  }

  Future<void> _confirmAndReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Infos zurücksetzen?'),
        content: const Text(
          'Alle Einträge werden gelöscht und aus der Vorlage neu erstellt (Cloud → Asset-Fallback).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Zurücksetzen')),
        ],
      ),
    );
    if (ok == true) {
      await _resetAndReseed();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Infos zurückgesetzt.')),
      );
    }
  }

  Future<void> _seedFromDefaults() async {
    try {
      final usedCloud = await _seedFromFirestore();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Infos aus ${usedCloud ? "Cloud" : "Asset"} geladen.')),
      );
    } catch (e) {
      try {
        await _seedFromAssets();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Infos aus Asset geladen.')),
        );
      } catch (e2) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Seed fehlgeschlagen: $e2')),
        );
      }
    }
  }

  Future<bool> _seedFromFirestore() async {
    final doc = await FirebaseFirestore.instance
        .collection('config')
        .doc('infos_default')
        .get();

    if (!doc.exists) {
      await _seedFromAssets();
      return false;
    }

    final data = doc.data()!;
    final dynamic raw = data['items'] ?? data;
    if (raw is! List) {
      await _seedFromAssets();
      return false;
    }

    final batch = FirebaseFirestore.instance.batch();
    int idx = 0;
    for (final entry in raw) {
      if (entry is String) {
        batch.set(_infoCol.doc(), {
          'title': entry,
          'details': null,
          'cashOnly': false,
          'link': null,
          'tags': null,
          'pinned': false,
          'order': idx++,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else if (entry is Map) {
        batch.set(_infoCol.doc(), {
          'title': (entry['title'] ?? '').toString(),
          'details': entry['details'],
          'cashOnly': entry['cashOnly'] ?? false,
          'link': entry['link'],
          'tags': entry['tags'],
          'pinned': entry['pinned'] ?? false,
          'order': idx++,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
    return true;
  }

  Future<void> _seedFromAssets() async {
    final jsonString = await rootBundle.loadString('assets/infos_default.json');
    final Map<String, dynamic> jsonData = jsonDecode(jsonString);
    final List items = jsonData['items'] ?? [];

    final batch = FirebaseFirestore.instance.batch();
    int idx = 0;
    for (final entry in items) {
      if (entry is String) {
        batch.set(_infoCol.doc(), {
          'title': entry,
          'details': null,
          'cashOnly': false,
          'link': null,
          'tags': null,
          'pinned': false,
          'order': idx++,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else if (entry is Map) {
        batch.set(_infoCol.doc(), {
          'title': (entry['title'] ?? '').toString(),
          'details': entry['details'],
          'cashOnly': entry['cashOnly'] ?? false,
          'link': entry['link'],
          'tags': entry['tags'],
          'pinned': entry['pinned'] ?? false,
          'order': idx++,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  }

  // ------------------- Index-Link Logging -------------------
  String? _extractFirebaseIndexLink(Object error) {
    final text = error.toString();
    final m = RegExp(r'https://console\.firebase\.google\.com[^\s)"]+').firstMatch(text);
    return m?.group(0);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _infoStream() {
    final q = _infoCol
        .orderBy('pinned', descending: true)
        .orderBy('order');

    return q.snapshots().handleError((e, _) {
      debugPrint('🔥 Firestore-Query-Fehler: $e');
      final link = _extractFirebaseIndexLink(e);
      if (link != null) {
        debugPrint('👉 Index anlegen: $link');
      }
    });
  }

  // ------------------- CRUD -------------------
  Future<void> _addOrEditInfo({DocumentSnapshot<Map<String, dynamic>>? doc}) async {
    final isEdit = doc != null;
    final data = doc?.data();
    final titleController = TextEditingController(text: data?['title']);
    final detailsController = TextEditingController(text: data?['details']);
    final linkController = TextEditingController(text: data?['link']);
    bool cashOnly = data?['cashOnly'] ?? false;
    bool pinned = data?['pinned'] ?? false;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? 'Info bearbeiten' : 'Neue Info'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Titel'),
              ),
              TextField(
                controller: detailsController,
                decoration: const InputDecoration(labelText: 'Details'),
                maxLines: 3,
              ),
              TextField(
                controller: linkController,
                decoration: const InputDecoration(labelText: 'Link (optional)'),
              ),
              SwitchListTile(
                title: const Text('Nur Bargeld'),
                value: cashOnly,
                onChanged: (v) => setState(() => cashOnly = v),
              ),
              SwitchListTile(
                title: const Text('Angepinnt'),
                value: pinned,
                onChanged: (v) => setState(() => pinned = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isEmpty) return;

              if (isEdit) {
                await _infoCol.doc(doc!.id).set({
                  'title': title,
                  'details': detailsController.text.trim().isEmpty
                      ? null
                      : detailsController.text.trim(),
                  'link': linkController.text.trim().isEmpty
                      ? null
                      : linkController.text.trim(),
                  'cashOnly': cashOnly,
                  'pinned': pinned,
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
              } else {
                final last = await _infoCol.orderBy('order', descending: true).limit(1).get();
                final nextOrder = last.docs.isEmpty
                    ? 0
                    : ((last.docs.first.data()['order'] as num?)?.toInt() ?? 0) + 1;

                await _infoCol.add({
                  'title': title,
                  'details': detailsController.text.trim().isEmpty
                      ? null
                      : detailsController.text.trim(),
                  'link': linkController.text.trim().isEmpty
                      ? null
                      : linkController.text.trim(),
                  'cashOnly': cashOnly,
                  'pinned': pinned,
                  'order': nextOrder,
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              }
              if (mounted) Navigator.pop(context);
            },
            child: Text(isEdit ? 'Speichern' : 'Hinzufügen'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteInfo(String id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eintrag löschen?'),
        content: Text('„$title“ wird dauerhaft gelöscht.'),
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
    if (confirmed == true) {
      await _infoCol.doc(id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('„$title“ gelöscht')),
        );
      }
    }
  }

  // ------------------- UI -------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final scaffold = Scaffold(
      appBar: AppBar(
        title: const Text('Infos'),
        actions: [
          IconButton(
            tooltip: 'Zurücksetzen',
            icon: const Icon(Icons.restart_alt),
            onPressed: _confirmAndReset,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _infoStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            // Link auch im UI-Fall in die Konsole schreiben
            final link = _extractFirebaseIndexLink(snap.error!);
            if (link != null) {
              debugPrint('👉 Index anlegen: $link');
            }
            return Center(child: Text('Fehler: ${snap.error}'));
          }
          final infos = snap.data?.docs ?? [];
          if (infos.isEmpty) {
            return const Center(child: Text('Noch keine Infos.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: infos.length,
            itemBuilder: (context, index) {
              final doc = infos[index];
              final data = doc.data();
              final title = (data['title'] ?? '').toString();
              final details = (data['details'] ?? '').toString();
              final link = data['link'] as String?;
              final cashOnly = data['cashOnly'] == true;
              final pinned = data['pinned'] == true;

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: cs.outlineVariant),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (details.isNotEmpty) Text(details),
                      if (cashOnly) const Text('💸 Nur Bargeld'),
                      if (link != null)
                        TextButton.icon(
                          icon: const Icon(Icons.link),
                          label: const Text('Öffnen'),
                          onPressed: () => launchUrl(Uri.parse(link)),
                        ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _addOrEditInfo(doc: doc);
                          break;
                        case 'delete':
                          _deleteInfo(doc.id, title);
                          break;
                        case 'pin':
                          _infoCol.doc(doc.id).set({'pinned': !pinned, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(leading: Icon(Icons.edit), title: Text('Bearbeiten')),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Löschen')),
                      ),
                      PopupMenuItem(
                        value: 'pin',
                        child: ListTile(
                          leading: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined),
                          title: Text(pinned ? 'Anheften lösen' : 'Anheften'),
                        ),
                      ),
                    ],
                  ),
                  onTap: () => _addOrEditInfo(doc: doc),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditInfo(),
        child: const Icon(Icons.add),
      ),
    );

    return AbsorbPointer(
      absorbing: _busy,
      child: Stack(
        children: [
          scaffold,
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
