import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/welcome_screen.dart';

void main() {
  runApp(const GarganoApp());
}

class GarganoApp extends StatefulWidget {
  const GarganoApp({super.key});

  @override
  State<GarganoApp> createState() => _GarganoAppState();
}

class _GarganoAppState extends State<GarganoApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('themeMode') ?? 'system';
    setState(() {
      _themeMode = _stringToThemeMode(mode);
    });
  }

  Future<void> _toggleThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_themeMode == ThemeMode.light) {
        _themeMode = ThemeMode.dark;
        prefs.setString('themeMode', 'dark');
      } else if (_themeMode == ThemeMode.dark) {
        _themeMode = ThemeMode.system;
        prefs.setString('themeMode', 'system');
      } else {
        _themeMode = ThemeMode.light;
        prefs.setString('themeMode', 'light');
      }
    });
  }

  ThemeMode _stringToThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gargano 2025',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: _themeMode,
      home: WelcomeScreen(onToggleTheme: _toggleThemeMode),
    );
  }
}
