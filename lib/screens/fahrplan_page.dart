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
  bool highlightFirst = false;

  final DateTime startTime = DateTime(2025, 8, 16, 22, 0);

  final List<Map<String, dynamic>> stops = const [
    {'time': '22:00', 'km': '1200', 'desc': 'Start München', 'highlight': true},
    {'time': '01:00', 'km': '1010', 'desc': 'Brenner – Maut 11 €, Vignette 9,90 €'},
    {'time': '01:30', 'km': '0970', 'desc': 'Autogrill Trento Nord – kurzer Stopp Kaffee/Toilette'},
    {'time': '03:00', 'km': '0850', 'desc': 'Schlafpause Rastplatz Verona/Modena (1 h)'},
    {'time': '05:00', 'km': '0750', 'desc': 'Bologna passieren (Nachtverkehr flüssig)'},
    {'time': '06:30', 'km': '0620', 'desc': 'Sonnenaufgang Adriaküste'},
    {'time': '07:00', 'km': '0520', 'desc': 'Autogrill Fano/Marotta – Frühstück + Tanken', 'highlight': true},
    {'time': '09:30', 'km': '0320', 'desc': 'Pescara Nord – Toilettenpause, Snacks'},
    {'time': '13:00', 'km': '0000', 'desc': 'Ankunft Camping Spiaggia Lunga (Check-in)'},
  ];

  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = startTime.difference(DateTime.now());
      if (remaining.isNegative && !highlightFirst) {
        setState(() {
          highlightFirst = true;
        });
        _scrollController.animateTo(
          0,
          duration: const Duration(seconds: 2),
          curve: Curves.easeInOut,
        );
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CountdownBanner(startTime: startTime),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: stops.length,
            itemBuilder: (context, index) {
              final stop = stops[index];
              final isHighlighted = highlightFirst && stop['highlight'] == true;
              return Card(
                color: isHighlighted
                    ? Colors.teal.shade200
                    : (stop['highlight'] == true
                        ? Colors.teal.shade100
                        : null),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Text(
                    stop['time']!,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  title: Text(
                    '${stop['km']} km',
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  subtitle: Text(
                    stop['desc']!,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
