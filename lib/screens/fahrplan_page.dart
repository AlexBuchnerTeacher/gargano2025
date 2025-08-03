import 'package:flutter/material.dart';
import 'dart:async';
import '../widgets/countdown_banner.dart';

class FahrplanPage extends StatefulWidget {
  const FahrplanPage({super.key});

  @override
  State<FahrplanPage> createState() => _FahrplanPageState();
}

class _FahrplanPageState extends State<FahrplanPage> {
  final ScrollController _scrollController = ScrollController();

  /// Index der aktuell gehighlighteten Card
  int? highlightIndex;

  /// Startzeit dynamisch
  DateTime startTime = DateTime(2025, 8, 16, 22, 0);

  /// Fahrplan-Einträge mit Offset (in Minuten) und Restkilometer
  final List<Map<String, dynamic>> stops = [
    {'offset': 0, 'km': 1200, 'desc': 'Start München'},
    {'offset': 180, 'km': 1010, 'desc': 'Brenner – Maut 11 €, Vignette 9,90 €'},
    {'offset': 210, 'km': 970, 'desc': 'Autogrill Trento Nord – kurzer Stopp Kaffee/Toilette'},
    {'offset': 300, 'km': 850, 'desc': 'Schlafpause Rastplatz Verona/Modena (1 h)'},
    {'offset': 420, 'km': 750, 'desc': 'Bologna passieren (Nachtverkehr flüssig)'},
    {'offset': 510, 'km': 620, 'desc': 'Sonnenaufgang Adriaküste'},
    {'offset': 540, 'km': 520, 'desc': 'Autogrill Fano/Marotta – Frühstück + Tanken'},
    {'offset': 690, 'km': 320, 'desc': 'Pescara Nord – Toilettenpause, Snacks'},
    {'offset': 900, 'km': 0, 'desc': 'Ankunft Camping Spiaggia Lunga (Check-in)'},
  ];

  @override
  void initState() {
    super.initState();

    // Alle Sekunde prüfen, welcher Stop aktuell ist
    Timer.periodic(const Duration(seconds: 1), (timer) {
      final index = _getCurrentStopIndex();
      if (index != highlightIndex) {
        setState(() {
          highlightIndex = index;
        });

        // Automatisch scrollen zur aktuellen Card
        final position = index * 100.0; // grobe Höhe einer Card
        _scrollController.animateTo(
          position,
          duration: const Duration(seconds: 2),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  /// Findet den Index des letzten erreichten Stops (<= jetzt)
  int _getCurrentStopIndex() {
    final now = DateTime.now();
    for (int i = stops.length - 1; i >= 0; i--) {
      final stopTime = startTime.add(Duration(minutes: stops[i]['offset']));
      if (stopTime.isBefore(now) || stopTime.isAtSameMomentAs(now)) {
        return i;
      }
    }
    return 0; // Noch kein Stop erreicht → Start
  }

  /// Methode zum Ändern der Startzeit
  Future<void> _pickStartDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: startTime,
      firstDate: DateTime(2025, 1, 1),
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

    final newDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      startTime = newDateTime;
      highlightIndex = null; // Reset Highlight
    });
  }

  /// Berechnet Uhrzeit-String aus Offset
  String _formatTime(int offsetMinutes) {
    final time = startTime.add(Duration(minutes: offsetMinutes));
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CountdownBanner(startTime: startTime),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
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
                  begin: 1.0,
                  end: isHighlighted ? 1.05 : 1.0,
                ),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isHighlighted
                            ? (Theme.of(context).brightness == Brightness.dark
                                ? Colors.teal.shade400 // Dunkler im Dark Mode
                                : Colors.teal.shade200) // Heller im Light Mode
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isHighlighted
                            ? [
                                BoxShadow(
                                  color: Colors.teal.withValues(alpha: 0.6),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                )
                              ]
                            : [],
                      ),
                      child: ListTile(
                        leading: Text(
                          _formatTime(stop['offset']),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isHighlighted
                                ? (Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black)
                                : null,
                          ),
                        ),
                        title: Text(
                          '${stop['km']} km',
                          style: TextStyle(
                            fontSize: 18,
                            color: isHighlighted
                                ? (Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black)
                                : Colors.grey,
                          ),
                        ),
                        subtitle: Text(
                          stop['desc'],
                          style: TextStyle(
                            fontSize: 16,
                            color: isHighlighted
                                ? (Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black)
                                : null,
                          ),
                        ),
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
  }
}
