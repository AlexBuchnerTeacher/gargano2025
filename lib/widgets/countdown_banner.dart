import 'package:flutter/material.dart';
import 'dart:async';

class CountdownBanner extends StatefulWidget {
  final DateTime startTime;

  const CountdownBanner({super.key, required this.startTime});

  @override
  State<CountdownBanner> createState() => _CountdownBannerState();
}

class _CountdownBannerState extends State<CountdownBanner> {
  late Timer _timer;
  late Duration _timeDiff;
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      if (now.isBefore(widget.startTime)) {
        _hasStarted = false;
        _timeDiff = widget.startTime.difference(now);
      } else {
        _hasStarted = true;
        _timeDiff = now.difference(widget.startTime);
      }
    });
  }

  String _formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (days > 0) {
      return '$days d ${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
    } else {
      return '${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _hasStarted ? Colors.green.shade700 : Colors.teal.shade700,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Text(
        _hasStarted
            ? 'Seit Start: ${_formatDuration(_timeDiff)}'
            : 'Start in: ${_formatDuration(_timeDiff)}',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
