import 'package:flutter/material.dart';
import 'dart:async';

class CountdownBanner extends StatefulWidget {
  final DateTime startTime;
  const CountdownBanner({super.key, required this.startTime});

  @override
  State<CountdownBanner> createState() => _CountdownBannerState();
}

class _CountdownBannerState extends State<CountdownBanner> {
  late Duration remaining;
  late Timer timer;

  @override
  void initState() {
    super.initState();
    remaining = widget.startTime.difference(DateTime.now());
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        remaining = widget.startTime.difference(DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (remaining.isNegative) return const SizedBox.shrink();

    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;

    return Container(
      color: Colors.teal,
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      child: Text(
        '$days T : $hours Std : $minutes Min : $seconds Sek',
        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }
}
