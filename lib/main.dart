// ====== IMPORTS ======
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Screens
import 'screens/welcome_screen.dart';

// ====== DEV: Einmal-Uploader-Schalter ======
// Für EINEN Lauf auf true setzen, App starten, danach wieder false!
const bool kDoOneTimeUpload = false;

// ====== DEV: Einmal-Uploader-Funktion ======
// Liest assets/checklist_default.json und legt config/checklist_default in Firestore an,
// falls es noch nicht existiert.
Future<void> uploadDefaultChecklistOnce() async {
  final docRef =
      FirebaseFirestore.instance.collection('config').doc('checklist_default');

  final exists = (await docRef.get()).exists;
  if (exists) {
    debugPrint('ℹ️ checklist_default existiert bereits – Upload übersprungen.');
    return;
  }

  final jsonString =
      await rootBundle.loadString('assets/checklist_default.json');
  final Map<String, dynamic> jsonData = jsonDecode(jsonString);

  // Serverseitigen Zeitstempel setzen
  jsonData['updatedAt'] = FieldValue.serverTimestamp();

  await docRef.set(jsonData, SetOptions(merge: false));
  debugPrint('✅ checklist_default erfolgreich nach Firestore hochgeladen.');
}

// ====== MAIN ======
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }

  // Für den Upload sicherstellen, dass wir angemeldet sind (z.B. anonym)
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }

  // Nur EINMAL ausführen: Schalter kurz auf true setzen, App starten, dann wieder false
  if (kDoOneTimeUpload) {
    await uploadDefaultChecklistOnce();
  }

  runApp(const GarganoApp());
}

// ====== APP WIDGET ======
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
    const lightScheme = ColorScheme.light(
      primary: Color(0xFFFF7A00),
      primaryContainer: Color(0xFFFFB347),
      secondary: Color(0xFF007A78),
      surface: Color(0xFFFFF3E0),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.black87,
    );

    const darkScheme = ColorScheme.dark(
      primary: Color(0xFFFF7A00),
      primaryContainer: Color(0xFFFFB347),
      secondary: Color(0xFF007A78),
      surface: Color(0xFF2B2B2B),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white70,
    );

    return MaterialApp(
      title: 'Gargano 2025',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightScheme,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
      ),
      themeMode: _themeMode,
      home: WelcomeScreen(onToggleTheme: _toggleThemeMode),
    );
  }
}
