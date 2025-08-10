import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_screen.dart';

class WelcomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const WelcomeScreen({super.key, required this.onToggleTheme});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // --- Profile-Konfiguration (ERSETZEN mit euren echten E-Mails in Firebase) ---
  static const String _emailGroupA = 'alex.buchner@gmx.de'; // Jonas/Christine/Alex
  static const String _emailGroupB = 'niklas.buchner@gmail.com'; // Niklas & Friends

  // UI/Login State
  bool _isGroupB = false; // false = Gruppe A, true = Gruppe B (Schiebeschalter)
  final TextEditingController _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String get _selectedEmail => _isGroupB ? _emailGroupB : _emailGroupA;
  String get _selectedLabel =>
      _isGroupB ? 'Niklas & Friends' : 'Jonas / Christine / Alex';

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _selectedEmail,
        password: _passwordCtrl.text,
      );
      // Erfolg: StreamBuilder zeigt automatisch die eingeloggte Ansicht
    } on FirebaseAuthException catch (e) {
      String msg = 'Anmeldung fehlgeschlagen.';
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        msg = 'Benutzer nicht gefunden oder falsche Zugangsdaten.';
      } else if (e.code == 'wrong-password') {
        msg = 'Passwort ist falsch.';
      } else if (e.code == 'too-many-requests') {
        msg = 'Zu viele Versuche. Bitte später erneut.';
      }
      setState(() => _error = msg);
    } catch (_) {
      setState(() => _error = 'Unerwarteter Fehler. Bitte erneut versuchen.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    _passwordCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    final colorScheme = Theme.of(context).colorScheme.copyWith(
          primary: const Color(0xFFFF7A00),
          primaryContainer: const Color(0xFFFFB347),
          secondary: const Color(0xFF007A78),
          surface: const Color(0xFFFFF3E0),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.black87,
        );

    return Theme(
      data: Theme.of(context).copyWith(colorScheme: colorScheme),
      child: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          final user = snap.data;

          // ---------- Nicht eingeloggt: Profil wählen + Passwort ----------
          if (user == null) {
            return Scaffold(
              backgroundColor: colorScheme.surface,
              body: SafeArea(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colorScheme.primary.withValues(alpha: 0.2),
                        colorScheme.surface,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: AnimatedBuilder(
                        animation: fadeAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity: fadeAnimation.value,
                            child: Transform.translate(
                              offset: Offset(0, 30 * (1 - fadeAnimation.value)),
                              child: child,
                            ),
                          );
                        },
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Logo
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 160),
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(24),
                                        boxShadow: [
                                          BoxShadow(
                                            blurRadius: 16,
                                            spreadRadius: 0,
                                            offset: const Offset(0, 8),
                                            color: Colors.black
                                                .withValues(alpha: 0.08),
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Image.asset(
                                          'assets/icons/app_icon.png',
                                          fit: BoxFit.contain,
                                          semanticLabel:
                                              'Gargano 2025 App-Logo',
                                          errorBuilder: (_, __, ___) => Icon(
                                            Icons.route,
                                            size: 96,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Profilwahl per Schiebeschalter
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: Colors.black.withValues(alpha: 0.08)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Profil wählen',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelLarge),
                                          const SizedBox(height: 4),
                                          Text(
                                            _selectedLabel,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                    fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _selectedEmail,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.6),
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _isGroupB,
                                      onChanged: (v) {
                                        setState(() {
                                          _isGroupB = v;
                                          _passwordCtrl.clear();
                                          _error = null;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              if (_error != null) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          Colors.red.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: Colors.red.shade800,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // Passwortfeld + Login
                              Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _passwordCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Passwort',
                                        border: OutlineInputBorder(),
                                      ),
                                      obscureText: true,
                                      validator: (v) {
                                        if (v == null || v.isEmpty) {
                                          return 'Bitte Passwort eingeben';
                                        }
                                        return null;
                                      },
                                      onFieldSubmitted: (_) => _signIn(),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: FilledButton.icon(
                                        onPressed: _isLoading ? null : _signIn,
                                        icon: _isLoading
                                            ? const SizedBox(
                                                height: 18,
                                                width: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(Icons.lock_open),
                                        label: Text(_isLoading
                                            ? 'Anmelden…'
                                            : 'Anmelden'),
                                        style: FilledButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Hinweis: Nur vordefinierte Benutzer. Keine Registrierung.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.black54),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          // ---------- Eingeloggt: dein bisheriger Welcome-Content ----------
          return Scaffold(
            backgroundColor: colorScheme.surface,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              actions: [
                IconButton(
                  tooltip: 'Abmelden',
                  icon: const Icon(Icons.logout),
                  onPressed: _signOut,
                ),
              ],
            ),
            body: SafeArea(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.2),
                      colorScheme.surface,
                    ],
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: AnimatedBuilder(
                      animation: fadeAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: fadeAnimation.value,
                          child: Transform.translate(
                            offset: Offset(0, 30 * (1 - fadeAnimation.value)),
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // --- LOGO ---
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        blurRadius: 16,
                                        spreadRadius: 0,
                                        offset: const Offset(0, 8),
                                        color: Colors.black
                                            .withValues(alpha: 0.08),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Image.asset(
                                      'assets/icons/app_icon.png',
                                      fit: BoxFit.contain,
                                      semanticLabel: 'Gargano 2025 App-Logo',
                                      errorBuilder: (_, __, ___) => Icon(
                                        Icons.route,
                                        size: 96,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // --- Titel ---
                          Text(
                            'Gargano 2025',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),

                          // --- Untertitel ---
                          Text(
                            'Dein Fahrplan München → Vieste\nmit Stopps, Restkilometern und Checkliste.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 48),

                          // --- Primary CTA ---
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Los geht’s'),
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MainScreen(
                                    onToggleTheme: widget.onToggleTheme,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          // --- Secondary CTA ---
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              side: BorderSide(color: colorScheme.primary),
                            ),
                            icon: const Icon(Icons.checklist),
                            label: const Text('Checkliste öffnen'),
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MainScreen(
                                    initialTab: 1,
                                    onToggleTheme: widget.onToggleTheme,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
