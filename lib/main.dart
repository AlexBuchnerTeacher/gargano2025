import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const GarganoApp());
}

class GarganoApp extends StatelessWidget {
  const GarganoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gargano 2025',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
    );
  }
}

// Welcome Screen
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

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
                    MaterialPageRoute(builder: (_) => const MainScreen()),
                  );
                },
                child: const Text('Los geht’s'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const MainScreen(initialTab: 1)),
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

// Hauptscreen mit Tabs
class MainScreen extends StatefulWidget {
  final int initialTab;
  const MainScreen({super.key, this.initialTab = 0});

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
    const Placeholder(), // Rückfahrt Platzhalter
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
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

// Fahrplan
class FahrplanPage extends StatelessWidget {
  const FahrplanPage({super.key});

  final List<Map<String, dynamic>> stops = const [
    {'time': '22:00', 'km': '1200', 'desc': 'Start München'},
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
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...stops.map((stop) {
          final highlight = stop['highlight'] == true;
          return Card(
            color: highlight ? Colors.teal.shade100 : null,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Text(
                stop['time']!,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              title: Text('${stop['km']} km', style: const TextStyle(fontSize: 18, color: Colors.grey)),
              subtitle: Text(stop['desc']!, style: const TextStyle(fontSize: 16)),
            ),
          );
        }),
        Card(
          color: Colors.teal.shade50,
          margin: const EdgeInsets.only(top: 16),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('Zusatzinformationen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 12),
                Text('Tankstrategie: Start vollgetankt, Tanken bei Frühstückspause (Fano/Marotta, Rest 520 km)'),
                Text('Mautkosten: AT 9,90 € + 11 €, IT ca. 65–70 €'),
                Text('Gesamtkosten Hinfahrt: ca. 210–220 € inkl. Diesel'),
                Text('Letzte 90 km (Gargano) kurvig – ca. 2 h Fahrtzeit einplanen'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Checkliste
class ChecklistPage extends StatefulWidget {
  const ChecklistPage({super.key});

  @override
  State<ChecklistPage> createState() => _ChecklistPageState();
}

class _ChecklistPageState extends State<ChecklistPage> {
  final List<String> checklistItems = [
    'Snacks griffbereit',
    'Wasserflaschen kalt',
    'Powerbank & Ladekabel',
    'Playlist / Hörbuch offline',
    'Vignette + Mautgeld',
    'Sonnenbrillen',
    'Müllbeutel',
    'Notfallapotheke',
  ];

  late List<bool> checkedState = List.filled(8, false);

  @override
  void initState() {
    super.initState();
    _loadChecklistState();
  }

  Future<void> _loadChecklistState() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('checklist') ?? [];
    if (saved.isNotEmpty && saved.length == checklistItems.length) {
      setState(() {
        checkedState = saved.map((e) => e == 'true').toList();
      });
    }
  }

  Future<void> _saveChecklistState() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList('checklist', checkedState.map((e) => e.toString()).toList());
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: checklistItems.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: CheckboxListTile(
            value: checkedState[index],
            onChanged: (val) {
              setState(() {
                checkedState[index] = val ?? false;
                _saveChecklistState();
              });
            },
            title: Text(checklistItems[index]),
          ),
        );
      },
    );
  }
}
