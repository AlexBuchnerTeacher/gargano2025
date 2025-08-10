import 'package:flutter/material.dart';
import 'fahrplan_page.dart';
import 'checklist_page.dart';

class MainScreen extends StatefulWidget {
  final int initialTab;
  final VoidCallback onToggleTheme;
  const MainScreen({super.key, this.initialTab = 0, required this.onToggleTheme});

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

  final List<Widget> _pages = [
    const FahrplanPage(),
    const ChecklistPage(),
    const Placeholder(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Gargano 2025'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.wb_sunny
                  : Icons.nightlight_round,
            ),
            onPressed: widget.onToggleTheme,
          ),
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
          NavigationDestination(icon: Icon(Icons.arrow_back), label: 'Rückfahrt'),
        ],
      ),
    );
  }
}
