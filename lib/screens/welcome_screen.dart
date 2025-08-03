import 'package:flutter/material.dart';
import 'main_screen.dart';

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onToggleTheme;
  const WelcomeScreen({super.key, required this.onToggleTheme});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Gargano 2025',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Dein Fahrplan München → Vieste\nmit Stopps, Restkilometern und Checkliste.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MainScreen(onToggleTheme: onToggleTheme),
                    ),
                  );
                },
                child: const Text('Los geht’s'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          MainScreen(initialTab: 1, onToggleTheme: onToggleTheme),
                    ),
                  );
                },
                child: const Text('Checkliste öffnen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
