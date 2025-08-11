import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/countdown_banner.dart';

class FahrplanPage extends StatefulWidget {
  const FahrplanPage({super.key});

  @override
  State<FahrplanPage> createState() => _FahrplanPageState();
}

class _FahrplanPageState extends State<FahrplanPage> {
  final ScrollController _scrollController = ScrollController();
  Timer? _ticker;
  int? highlightIndex;

  // ---- Firebase Pfade ----
  final String _tripId = 'default'; // kannst du später dynamisch machen
  late final String _uid;
  late final DocumentReference<Map<String, dynamic>> _metaDoc;
  late final CollectionReference<Map<String, dynamic>> _itineraryCol;

  // Startzeit (kommt aus Firestore -> meta.startTime)
  DateTime startTime = DateTime(2025, 8, 16, 22, 0);

  // Fallback-/Seed-Daten (werden 1x in Firestore geschrieben, falls leer)
  final List<Map<String, dynamic>> _sampleStops = const [
    {
      'offset': 0,
      'km': 1120,
      'desc': 'Start München',
      'link':
          'https://www.google.com/maps/search/?api=1&query=Munich%2C+Germany'
    },
    {
      'offset': 150,
      'km': 955,
      'desc': 'Brenner – Maut 12 € pro Richtung, AT‑Vignette ~9,90 €',
      'link':
          'https://www.google.com/maps/search/?api=1&query=Brennerpass+Mautstation'
    },
    {
      'offset': 210,
      'km': 855,
      'desc': 'Trento Nord – kurzer Stopp (Kaffee/Toilette)',
      'link': 'https://www.google.com/maps/search/?api=1&query=Trento+Nord'
    },
    {
      'offset': 300,
      'km': 735,
      'desc': 'Verona/Modena – Schlafpause ca. 1 h',
      'link': 'https://www.google.com/maps/search/?api=1&query=Modena'
    },
    {
      'offset': 420,
      'km': 590,
      'desc': 'Bologna passieren (früher Morgen)',
      'link': 'https://www.google.com/maps/search/?api=1&query=Bologna'
    },
    {
      'offset': 510,
      'km': 510,
      'desc': 'Adriaküste (Rimini) – Sonnenaufgang',
      'link': 'https://www.google.com/maps/search/?api=1&query=Rimini'
    },
    {
      'offset': 570,
      'km': 430,
      'desc': 'Fano/Marotta – Frühstück + Tanken',
      'link': 'https://www.google.com/maps/search/?api=1&query=Marotta%2C+Fano'
    },
    {
      'offset': 690,
      'km': 230,
      'desc': 'Pescara Nord – kurze Pause',
      'link': 'https://www.google.com/maps/search/?api=1&query=Pescara+Nord'
    },
    {
      'offset': 900,
      'km': 0,
      'desc': 'Ankunft Camping Spiaggia Lunga (Check‑in)',
      'link':
          'https://www.google.com/maps/search/?api=1&query=Camping+Spiaggia+Lunga+Vieste'
    },
  ];

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Sollte nicht passieren, da WelcomeScreen vorher Login erzwingt.
      throw StateError('Kein Benutzer eingeloggt.');
    }
    _uid = user.uid;

    final base = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('trips')
        .doc(_tripId);
    _metaDoc = base
        .collection('meta')
        .doc('main'); // /users/{uid}/trips/{tripId}/meta/main
    _itineraryCol =
        base.collection('itinerary'); // /users/{uid}/trips/{tripId}/itinerary

    _initMetaAndTicker();
  }

  Future<void> _initMetaAndTicker() async {
    // Meta laden (oder anlegen)
    final snap = await _metaDoc.get();
    if (snap.exists) {
      final data = snap.data();
      final ts = data?['startTime'] as Timestamp?;
      if (ts != null) startTime = ts.toDate();
    } else {
      await _metaDoc.set({
        'startTime': Timestamp.fromDate(startTime),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Itinerary ggf. seeden (einmalig, wenn leer)
    final itSnap = await _itineraryCol.limit(1).get();
    if (itSnap.size == 0) {
      await _seedItineraryUsingSampleStops();
    }

    // Auto-Highlight-Ticker
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;
      final index = _currentStopIndexFromStreamCache ?? 0;
      if (index != highlightIndex) {
        setState(() {
          highlightIndex = index;
        });
        final position = index * 100.0;
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            position,
            duration: const Duration(seconds: 2),
            curve: Curves.easeInOut,
          );
        }
      }
    });

    if (mounted) setState(() {});
  }

  Future<void> _seedItineraryUsingSampleStops() async {
    final batch = FirebaseFirestore.instance.batch();
    for (var stop in _sampleStops) {
      final docRef = _itineraryCol.doc(); // auto id
      batch.set(docRef, {
        'offset': stop['offset'],
        'km': stop['km'],
        'desc': stop['desc'],
        'link': stop['link'],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  int _getCurrentStopIndex(List<Map<String, dynamic>> stops) {
    final now = DateTime.now();
    final minutesSinceStart = now.difference(startTime).inMinutes;
    int currentIndex = 0;
    for (int i = 0; i < stops.length; i++) {
      final off = (stops[i]['offset'] as int?) ?? 0;
      if (minutesSinceStart >= off) {
        currentIndex = i;
      } else {
        break;
      }
    }
    return currentIndex;
  }

  Future<void> _pickStartDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: startTime,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2026, 12, 31),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(startTime),
    );
    if (time == null || !mounted) return;

    final newDateTime =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);

    await _metaDoc.set(
      {
        'startTime': Timestamp.fromDate(newDateTime),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    setState(() {
      startTime = newDateTime;
      highlightIndex = null;
    });
  }

  String _formatTime(int offsetMinutes) {
    final time = startTime.add(Duration(minutes: offsetMinutes));
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  void _openMapLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konnte den Link nicht öffnen.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Öffnen: $e')),
        );
      }
    }
  }

  // Cache für Stream-Highlight
  List<Map<String, dynamic>> _latestStops = const [];
  int? get _currentStopIndexFromStreamCache =>
      _latestStops.isEmpty ? null : _getCurrentStopIndex(_latestStops);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme.copyWith(
          primary: const Color(0xFFFF7A00),
          primaryContainer: const Color(0xFFFFB347),
          secondary: const Color(0xFF007A78),
          surface: const Color(0xFFFFF3E0),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.black87,
        );

    return Theme(
      data: Theme.of(context).copyWith(colorScheme: colorScheme),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _itineraryCol.orderBy('offset').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Fehler beim Laden des Fahrplans:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          final stops = docs
              .map((d) => {
                    'id': d.id,
                    'offset': (d.data()['offset'] as num?)?.toInt() ?? 0,
                    'km': (d.data()['km'] as num?)?.toInt() ?? 0,
                    'desc': d.data()['desc'] as String? ?? '',
                    'link': d.data()['link'] as String? ?? '',
                  })
              .toList();

          // Cache für laufende Highlight-Berechnung
          _latestStops = stops;

          final int maxOffset = stops.isEmpty
              ? 0
              : stops
                  .map<int>((e) => e['offset'] as int)
                  .reduce((a, b) => a > b ? a : b);
          final DateTime arrival = startTime.add(Duration(minutes: maxOffset));

          return Column(
            children: [
              CountdownBanner(startTime: startTime),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Ankunft (geplant): '
                  '${arrival.day.toString().padLeft(2, '0')}.'
                  '${arrival.month.toString().padLeft(2, '0')}.'
                  '${arrival.year} • '
                  '${arrival.hour.toString().padLeft(2, '0')}:'
                  '${arrival.minute.toString().padLeft(2, '0')} (~13:00)',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: FilledButton.icon(
                  onPressed: _pickStartDateTime,
                  icon: const Icon(Icons.edit),
                  label: const Text('Startzeit ändern'),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: stops.length,
                  itemBuilder: (context, index) {
                    final stop = stops[index];
                    final isHighlighted = highlightIndex == index;

                    return TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                          begin: 1.0, end: isHighlighted ? 1.05 : 1.0),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: isHighlighted
                                ? colorScheme.primaryContainer
                                : colorScheme.surface,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: isHighlighted ? 4 : 1,
                            child: ListTile(
                              onTap: () => (stop['link'] as String).isNotEmpty
                                  ? _openMapLink(stop['link'] as String)
                                  : null,
                              leading: Icon(Icons.access_time,
                                  color: isHighlighted
                                      ? colorScheme.onPrimary
                                      : colorScheme.primary),
                              title: Text(
                                '${_formatTime(stop['offset'] as int)}  •  ${stop['km']} km',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: isHighlighted
                                          ? colorScheme.onPrimary
                                          : colorScheme.onSurface,
                                    ),
                              ),
                              subtitle: Text(
                                stop['desc'] as String,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: isHighlighted
                                          ? colorScheme.onPrimary
                                          : colorScheme.onSurface,
                                    ),
                              ),
                              trailing: const Icon(Icons.map),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
