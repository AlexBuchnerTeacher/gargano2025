import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
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
  DateTime startTime = DateTime(2025, 8, 16, 22, 0);

  final List<Map<String, dynamic>> stops = [
    {'offset': 0, 'km': 1120, 'desc': 'Start München', 'link': 'https://maps.app.goo.gl/DLk4kMQUCWrUEZxE8'},
    {'offset': 150, 'km': 955, 'desc': 'Brenner – Maut ~11 €, AT-Vignette ~9,90 €', 'link': 'https://maps.app.goo.gl/zWcTqotmURBKQzKL9'},
    {'offset': 210, 'km': 855, 'desc': 'Trento Nord – kurzer Stopp (Kaffee/Toilette)', 'link': 'https://maps.app.goo.gl/1G3F2pMjSLjGGz3s7'},
    {'offset': 300, 'km': 735, 'desc': 'Verona/Modena – Schlafpause ca. 1 h', 'link': 'https://maps.app.goo.gl/qrxK3X3q2GbmHH5M8'},
    {'offset': 420, 'km': 590, 'desc': 'Bologna passieren (früher Morgen)', 'link': 'https://maps.app.goo.gl/tGbFfQKULfKjQGcc7'},
    {'offset': 510, 'km': 510, 'desc': 'Adriaküste (Rimini) – Sonnenaufgang', 'link': 'https://maps.app.goo.gl/7YoVGEy5w3FTtAxG9'},
    {'offset': 570, 'km': 430, 'desc': 'Fano/Marotta – Frühstück + Tanken', 'link': 'https://maps.app.goo.gl/o1kk27wwHyxVxG9c6'},
    {'offset': 690, 'km': 230, 'desc': 'Pescara Nord – kurze Pause', 'link': 'https://maps.app.goo.gl/DqD1F3pk5nrTfs4h6'},
    {'offset': 900, 'km': 0, 'desc': 'Ankunft Camping Spiaggia Lunga (Check-in)', 'link': 'https://maps.app.goo.gl/mhuv5CDfZ7aEkzPQ8'},
  ];

  Future<void> _loadSavedStartTime() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString('fahrplan_start_iso');
    if (iso != null) {
      final parsed = DateTime.tryParse(iso);
      if (parsed != null) {
        if (!mounted) return;
        setState(() {
          startTime = parsed;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSavedStartTime();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final index = _getCurrentStopIndex();
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
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  int _getCurrentStopIndex() {
    final now = DateTime.now();
    final minutesSinceStart = now.difference(startTime).inMinutes;
    int currentIndex = 0;
    for (int i = 0; i < stops.length; i++) {
      if (minutesSinceStart >= (stops[i]['offset'] as int)) {
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
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(startTime),
    );
    if (time == null) return;
    if (!mounted) return;
    final newDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      startTime = newDateTime;
      highlightIndex = null;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fahrplan_start_iso', newDateTime.toIso8601String());
  }

  String _formatTime(int offsetMinutes) {
    final time = startTime.add(Duration(minutes: offsetMinutes));
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme.copyWith(
      primary: const Color(0xFFFF7A00), // Orange aus dem Icon
      primaryContainer: const Color(0xFFFFB347), // Helles Orange
      secondary: const Color(0xFF007A78), // Türkis aus dem Meer
      surface: const Color(0xFFFFF3E0), // Sandfarbener Hintergrund
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.black87,
    );
    final int maxOffset = stops.map<int>((e) => e['offset'] as int).fold(0, (a, b) => a > b ? a : b);
    final DateTime arrival = startTime.add(Duration(minutes: maxOffset));
    return Theme(
      data: Theme.of(context).copyWith(colorScheme: colorScheme),
      child: Column(
        children: [
          CountdownBanner(startTime: startTime),
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Ankunft (geplant): ${arrival.day.toString().padLeft(2, '0')}.${arrival.month.toString().padLeft(2, '0')}.${arrival.year} • ${arrival.hour.toString().padLeft(2, '0')}:${arrival.minute.toString().padLeft(2, '0')} (~13:00)',
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
                  tween: Tween<double>(begin: 1.0, end: isHighlighted ? 1.05 : 1.0),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: isHighlighted ? colorScheme.primaryContainer : colorScheme.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: isHighlighted ? 4 : 1,
                        child: ListTile(
                          onTap: () => stop['link'] != null ? _openMapLink(stop['link']) : null,
                          leading: Icon(Icons.access_time, color: isHighlighted ? colorScheme.onPrimary : colorScheme.primary),
                          title: Text(
                            '${_formatTime(stop['offset'])}  •  ${stop['km']} km',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: isHighlighted ? colorScheme.onPrimary : colorScheme.onSurface,
                                ),
                          ),
                          subtitle: Text(
                            stop['desc'],
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: isHighlighted ? colorScheme.onPrimary : colorScheme.onSurface,
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
      ),
    );
  }

  void _openMapLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
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
}
