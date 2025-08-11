import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'fahrplan_page.dart';
import 'checklist_page.dart';
import 'welcome_screen.dart'; // für Navigation zurück zum Login
import 'infos_tab.dart';      // NEU: Info-Tab
// Reisekosten-Screen (aus Feature-Paket)
import 'package:gargano2025/features/reisekosten/reisekosten_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialTab;
  final VoidCallback onToggleTheme;

  const MainScreen({
    super.key,
    this.initialTab = 0,
    required this.onToggleTheme,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab;
  }

  // Seiten (const wo möglich)
  final List<Widget> _pages = const [
    FahrplanPage(),
    ChecklistPage(),
    ReisekostenScreen(),
    InfosTab(), // NEU
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      // Komplett zurück auf den Login-Bildschirm (alle Routen entfernen)
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => WelcomeScreen(onToggleTheme: widget.onToggleTheme),
        ),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Abmelden fehlgeschlagen')),
      );
    }
  }

  String _userLabel(User? u) {
    if (u == null) return '';
    if ((u.displayName ?? '').trim().isNotEmpty) return u.displayName!.trim();
    final mail = u.email ?? '';
    final name = mail.contains('@') ? mail.split('@').first : mail;
    return name.isEmpty ? '' : name;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        return Scaffold(
          backgroundColor: colorScheme.surface,
          appBar: AppBar(
            title: const Text('Gargano 2025'),
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            actions: [
              // Theme Toggle
              IconButton(
                tooltip: Theme.of(context).brightness == Brightness.dark
                    ? 'Helles Design'
                    : 'Dunkles Design',
                icon: Icon(
                  Theme.of(context).brightness == Brightness.dark
                      ? Icons.wb_sunny
                      : Icons.nightlight_round,
                ),
                onPressed: widget.onToggleTheme,
              ),

              // Username + Logout nur anzeigen, wenn eingeloggt
              if (user != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Text(
                        _userLabel(user),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Abmelden',
                  icon: const Icon(Icons.logout),
                  color: colorScheme.onPrimary,
                  onPressed: _signOut,
                ),
              ],
            ],
          ),
          body: _pages[_selectedIndex],
          bottomNavigationBar: NavigationBar(
            backgroundColor: colorScheme.surface,
            indicatorColor: colorScheme.primary.withValues(alpha: 0.2),
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.route), label: 'Fahrplan'),
              NavigationDestination(icon: Icon(Icons.checklist), label: 'Checkliste'),
              NavigationDestination(icon: Icon(Icons.local_gas_station), label: 'Kosten'),
              NavigationDestination(icon: Icon(Icons.info_outline), label: 'Infos'), // NEU
            ],
          ),
        );
      },
    );
  }
}
