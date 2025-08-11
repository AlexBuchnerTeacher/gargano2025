import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'reisekosten_calculator.dart';

class ReisekostenScreen extends StatefulWidget {
  const ReisekostenScreen({super.key});

  @override
  State<ReisekostenScreen> createState() => _ReisekostenScreenState();
}

class _ReisekostenScreenState extends State<ReisekostenScreen> {
  ReisekostenCalculator? _calc;

  // Firebase-Pfade
  final String _tripId = 'default';
  late final String _uid;
  late final DocumentReference<Map<String, dynamic>> _prefsDoc;

  // UI-State
  bool _roundTrip = true;
  bool _twoVignettes = false;
  bool _useCustomFuelPrice = false;

  double _consumption = 7.0;       // L/100 km
  double _customFuelPrice = 1.88;  // €/L

  CostBreakdown? _result;

  final TextEditingController _consumptionCtrl =
      TextEditingController(text: '7,0');
  final TextEditingController _fuelPriceCtrl =
      TextEditingController(text: '1,88');

  bool _loading = true;
  Timer? _debounce; // für onChanged-Debounce

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Kein Benutzer eingeloggt.');
    _uid = user.uid;
    _prefsDoc = FirebaseFirestore.instance
        .collection('users').doc(_uid)
        .collection('trips').doc(_tripId)
        .collection('costs').doc('userPrefs');
    _init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _consumptionCtrl.dispose();
    _fuelPriceCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final calc = await ReisekostenCalculator.loadFromAssets();
      final defCons = calc.config.vehicle.consumptionLPer100km;
      final defPrice = calc.config.fuelPrices.blended();

      final snap = await _prefsDoc.get();
      if (snap.exists) {
        final d = snap.data()!;
        _roundTrip = (d['roundTrip'] as bool?) ?? true;
        _twoVignettes = (d['twoVignettes'] as bool?) ?? false;
        _useCustomFuelPrice = (d['useCustomFuelPrice'] as bool?) ?? false;
        _consumption = (d['consumption'] as num?)?.toDouble() ?? defCons;
        _customFuelPrice = (d['customFuelPrice'] as num?)?.toDouble() ?? defPrice;
      } else {
        _roundTrip = true;
        _twoVignettes = false;
        _useCustomFuelPrice = false;
        _consumption = defCons;
        _customFuelPrice = defPrice;
        await _prefsDoc.set({
          'roundTrip': _roundTrip,
          'twoVignettes': _twoVignettes,
          'useCustomFuelPrice': _useCustomFuelPrice,
          'consumption': _consumption,
          'customFuelPrice': _customFuelPrice,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      _consumptionCtrl.text = _fmtNumber(_consumption);
      _fuelPriceCtrl.text = _fmtNumber(_customFuelPrice);

      setState(() {
        _calc = calc;
        _loading = false;
      });
      _recalcAndSave(); // initial
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Laden: $e')),
      );
    }
  }

  // -------- helpers --------
  String _fmtCurrency(double v) => '${v.toStringAsFixed(2).replaceAll('.', ',')} €';
  String _fmtNumber(double v) => v.toStringAsFixed(2).replaceAll('.', ',');
  double _parseNum(String s, {double fallback = 0}) =>
      double.tryParse(s.replaceAll(',', '.')) ?? fallback;

  Future<void> _save() async {
    await _prefsDoc.set({
      'roundTrip': _roundTrip,
      'twoVignettes': _twoVignettes,
      'useCustomFuelPrice': _useCustomFuelPrice,
      'consumption': _consumption,
      'customFuelPrice': _customFuelPrice,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _recalcAndSave() async {
    if (_calc == null) return;

    _consumption = _parseNum(_consumptionCtrl.text, fallback: _consumption);
    _customFuelPrice = _parseNum(_fuelPriceCtrl.text, fallback: _customFuelPrice);

    final price = _useCustomFuelPrice ? _customFuelPrice : null;
    final res = _calc!.calculate(
      roundTrip: _roundTrip,
      twoVignettes: _twoVignettes,
      customFuelPricePerL: price,
      customConsumptionLPer100: _consumption,
    );
    setState(() => _result = res);

    // Firestore speichern
    await _save();
  }

  // Debounced Auto-Calculate & Save (für Textfelder)
  void _scheduleRecalcSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _recalcAndSave);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _calc == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final routeName = _calc!.config.route.name;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('Reisekosten – $routeName')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Basisparameter
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  title: const Text('Hin & Zurück'),
                  value: _roundTrip,
                  onChanged: (v) {
                    setState(() => _roundTrip = v);
                    _recalcAndSave();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _consumptionCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Verbrauch (L/100 km)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _scheduleRecalcSave(),
                  onEditingComplete: () {
                    _consumption = _parseNum(_consumptionCtrl.text, fallback: _consumption);
                    _consumptionCtrl.text = _fmtNumber(_consumption);
                    _recalcAndSave();
                  },
                  onSubmitted: (_) {
                    _consumption = _parseNum(_consumptionCtrl.text, fallback: _consumption);
                    _consumptionCtrl.text = _fmtNumber(_consumption);
                    _recalcAndSave();
                  },
                ),
              ),
            ],
          ),

          // 2× Vignette Checkbox
          CheckboxListTile(
            title: const Text('Länger als 10 Tage (2× Ö‑Vignette)'),
            value: _twoVignettes,
            onChanged: (v) {
              setState(() => _twoVignettes = v ?? false);
              _recalcAndSave();
            },
          ),

          const SizedBox(height: 12),

          // Kraftstoffpreis
          SwitchListTile(
            title: const Text('Eigenen Kraftstoffpreis verwenden'),
            subtitle: Text(_useCustomFuelPrice
                ? 'Aktuell: ${_fmtNumber(_customFuelPrice)} €/L'
                : 'Gemittelter Preis (DE/AT/IT) aus der Config'),
            value: _useCustomFuelPrice,
            onChanged: (v) {
              setState(() => _useCustomFuelPrice = v);
              _recalcAndSave();
            },
          ),
          if (_useCustomFuelPrice)
            TextField(
              controller: _fuelPriceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Preis (€/L)',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _scheduleRecalcSave(),
              onEditingComplete: () {
                _customFuelPrice = _parseNum(_fuelPriceCtrl.text, fallback: _customFuelPrice);
                _fuelPriceCtrl.text = _fmtNumber(_customFuelPrice);
                _recalcAndSave();
              },
              onSubmitted: (_) {
                _customFuelPrice = _parseNum(_fuelPriceCtrl.text, fallback: _customFuelPrice);
                _fuelPriceCtrl.text = _fmtNumber(_customFuelPrice);
                _recalcAndSave();
              },
            ),

          const SizedBox(height: 16),

          // Ergebnisse
          if (_result != null) _buildResultCard(_result!, context, cs),
        ],
      ),
      // Kein FAB mehr – alles automatisch
    );
  }

  Widget _buildResultCard(CostBreakdown r, BuildContext context, ColorScheme cs) {
    final theme = Theme.of(context);
    final caption = TextStyle(color: cs.onSurface.withValues(alpha: 0.6));

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Kopf
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  r.roundTrip ? 'Hin & Zurück' : 'Nur Hinfahrt',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text('${r.distanceKm.toStringAsFixed(0)} km',
                    style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),

            // Kurzinfos
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Kraftstoff: ${r.litersNeeded.toStringAsFixed(1)} L'),
                Text('Preis: ${_fmtNumber(r.fuelPriceUsed)} €/L'),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Annahme: Ö‑Vignette ${r.twoVignettes ? '2× (Reisedauer > 10 Tage)' : '1×'} · '
                'Brenner ${r.roundTrip ? '2×' : '1×'} · Italien‑Maut inkl. beide Abschnitte',
                style: caption,
              ),
            ),

            const Divider(height: 24),

            _line('Kraftstoffkosten', _fmtCurrency(r.fuelCost), weight: FontWeight.w600),
            const SizedBox(height: 8),

            Align(
              alignment: Alignment.centerLeft,
              child: Text('Maut / Vignetten',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 6),
            _line('Ö 10‑Tages‑Vignette', _fmtCurrency(r.tollAustriaVignette)),
            _line('Brenner (Videomaut)', _fmtCurrency(r.tollBrenner)),
            _line('Italien Autobahn gesamt', _fmtCurrency(r.tollItaly)),
            const SizedBox(height: 8),
            _line('Summe Maut', _fmtCurrency(r.tollTotal), weight: FontWeight.w600),

            const Divider(height: 24),
            _line('GESAMTKOSTEN', _fmtCurrency(r.total), weight: FontWeight.w800, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _line(String left, String right,
      {FontWeight weight = FontWeight.w400, double size = 14}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(left, style: TextStyle(fontWeight: weight, fontSize: size))),
        Text(right, style: TextStyle(fontWeight: weight, fontSize: size)),
      ],
    );
  }
}
