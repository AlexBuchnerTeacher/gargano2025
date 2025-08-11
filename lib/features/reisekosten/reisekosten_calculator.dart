import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// -------------------------------
/// Datenmodelle
/// -------------------------------

class RouteConfig {
  final String name;
  final double distanceKmOneWay;
  final double distanceKmRoundTrip;

  const RouteConfig({
    required this.name,
    required this.distanceKmOneWay,
    required this.distanceKmRoundTrip,
  });

  factory RouteConfig.fromJson(Map<String, dynamic> json) => RouteConfig(
        name: json['route']['name'] as String,
        distanceKmOneWay:
            (json['route']['distance_km_one_way'] as num).toDouble(),
        distanceKmRoundTrip:
            (json['route']['distance_km_round_trip'] as num).toDouble(),
      );
}

class VehicleConfig {
  final String fuelType; // "Benzin" | "Diesel"
  final double consumptionLPer100km;

  const VehicleConfig({
    required this.fuelType,
    required this.consumptionLPer100km,
  });

  factory VehicleConfig.fromJson(Map<String, dynamic> json) => VehicleConfig(
        fuelType: json['vehicle']['fuel_type'] as String,
        consumptionLPer100km:
            (json['vehicle']['consumption_l_per_100km'] as num).toDouble(),
      );
}

class FuelPrices {
  final double germany; // €/L
  final double austria; // €/L
  final double italy; // €/L

  const FuelPrices({
    required this.germany,
    required this.austria,
    required this.italy,
  });

  factory FuelPrices.fromJson(Map<String, dynamic> json) => FuelPrices(
        germany: (json['fuel_prices']['germany'] as num).toDouble(),
        austria: (json['fuel_prices']['austria'] as num).toDouble(),
        italy: (json['fuel_prices']['italy'] as num).toDouble(),
      );

  /// Einfacher gemittelter Preis (DE/AT/IT).
  double blended() => (germany + austria + italy) / 3.0;
}

class TollsConfig {
  final double austriaVignette; // 10-Tages-Vignette
  final bool austriaVignetteNeededRoundtrip; // bleibt als Infoflag
  final double brennerPerDirection; // € je Richtung
  final double italySection1PerDirection; // Brenner–Modena
  final double italySection2PerDirection; // Modena–Vieste

  const TollsConfig({
    required this.austriaVignette,
    required this.austriaVignetteNeededRoundtrip,
    required this.brennerPerDirection,
    required this.italySection1PerDirection,
    required this.italySection2PerDirection,
  });

  factory TollsConfig.fromJson(Map<String, dynamic> json) => TollsConfig(
        austriaVignette: (json['tolls']['austria_vignette'] as num).toDouble(),
        austriaVignetteNeededRoundtrip:
            (json['tolls']['austria_vignette_needed_roundtrip'] as bool? ??
                true),
        brennerPerDirection:
            (json['tolls']['brenner_per_direction'] as num).toDouble(),
        italySection1PerDirection:
            (json['tolls']['italy_section1_per_direction'] as num).toDouble(),
        italySection2PerDirection:
            (json['tolls']['italy_section2_per_direction'] as num).toDouble(),
      );
}

class ReisekostenConfig {
  final RouteConfig route;
  final VehicleConfig vehicle;
  final FuelPrices fuelPrices;
  final TollsConfig tolls;

  const ReisekostenConfig({
    required this.route,
    required this.vehicle,
    required this.fuelPrices,
    required this.tolls,
  });

  factory ReisekostenConfig.fromJson(Map<String, dynamic> json) =>
      ReisekostenConfig(
        route: RouteConfig.fromJson(json),
        vehicle: VehicleConfig.fromJson(json),
        fuelPrices: FuelPrices.fromJson(json),
        tolls: TollsConfig.fromJson(json),
      );
}

/// Detail-Ergebnis der Berechnung zur UI-Anzeige
class CostBreakdown {
  final bool roundTrip;
  final bool twoVignettes; // UI-Checkbox-Status
  final double distanceKm;
  final double litersNeeded;
  final double fuelPriceUsed; // €/L
  final double fuelCost; // €
  final double tollAustriaVignette; // €
  final double tollBrenner; // €
  final double tollItaly; // €
  double get tollTotal => tollAustriaVignette + tollBrenner + tollItaly;
  double get total => fuelCost + tollTotal;

  const CostBreakdown({
    required this.roundTrip,
    required this.twoVignettes,
    required this.distanceKm,
    required this.litersNeeded,
    required this.fuelPriceUsed,
    required this.fuelCost,
    required this.tollAustriaVignette,
    required this.tollBrenner,
    required this.tollItaly,
  });

  Map<String, dynamic> toJson() => {
        'roundTrip': roundTrip,
        'twoVignettes': twoVignettes,
        'distanceKm': distanceKm,
        'litersNeeded': litersNeeded,
        'fuelPriceUsed': fuelPriceUsed,
        'fuelCost': fuelCost,
        'tollAustriaVignette': tollAustriaVignette,
        'tollBrenner': tollBrenner,
        'tollItaly': tollItaly,
        'tollTotal': tollTotal,
        'total': total,
      };
}

/// -------------------------------
/// Loader & Calculator
/// -------------------------------

class ReisekostenCalculator {
  static const String defaultConfigAssetPath =
      'assets/data/reisekosten_config.json';

  final ReisekostenConfig config;

  const ReisekostenCalculator(this.config);

  /// Lädt die JSON-Config aus den Assets.
  static Future<ReisekostenCalculator> loadFromAssets(
      {String assetPath = defaultConfigAssetPath}) async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final jsonMap = json.decode(raw) as Map<String, dynamic>;
      final cfg = ReisekostenConfig.fromJson(jsonMap);
      return ReisekostenCalculator(cfg);
    } catch (_) {
      // Fallback, falls Asset fehlt/fehlerhaft ist.
      const fallback = ReisekostenConfig(
        route: RouteConfig(
          name: 'München – Vieste',
          distanceKmOneWay: 1170,
          distanceKmRoundTrip: 2340,
        ),
        vehicle: VehicleConfig(
          fuelType: 'Benzin',
          consumptionLPer100km: 7.0,
        ),
        fuelPrices: FuelPrices(
          germany: 1.85,
          austria: 1.75,
          italy: 1.95,
        ),
        tolls: TollsConfig(
          austriaVignette: 9.90,
          austriaVignetteNeededRoundtrip: true,
          brennerPerDirection: 12.00, // ← aktualisiert
          italySection1PerDirection: 25.00,
          italySection2PerDirection: 45.00,
        ),
      );
      return const ReisekostenCalculator(fallback);
    }
  }

  /// Benötigte Liter.
  double litersNeeded({
    required bool roundTrip,
    double? customConsumptionLPer100,
  }) {
    final distance = roundTrip
        ? config.route.distanceKmRoundTrip
        : config.route.distanceKmOneWay;
    final consumption =
        customConsumptionLPer100 ?? config.vehicle.consumptionLPer100km;
    return (distance / 100.0) * consumption;
  }

  /// Mautkosten: Vignette (1× / 2×), Brenner je Richtung, Italien je Richtung.
  ({double austriaVignette, double brenner, double italy}) tolls({
    required bool roundTrip,
    required bool twoVignettes,
  }) {
    final t = config.tolls;

    final vignette = roundTrip
        ? (twoVignettes ? (t.austriaVignette * 2) : t.austriaVignette)
        : t.austriaVignette;

    final brenner =
        roundTrip ? (t.brennerPerDirection * 2) : t.brennerPerDirection;

    final italyPerDirection =
        t.italySection1PerDirection + t.italySection2PerDirection;
    final italy = roundTrip ? (italyPerDirection * 2) : italyPerDirection;

    return (austriaVignette: vignette, brenner: brenner, italy: italy);
  }

  /// Kompletter Kostenausweis.
  CostBreakdown calculate({
    required bool roundTrip,
    required bool twoVignettes,
    double? customFuelPricePerL,
    double? customConsumptionLPer100,
  }) {
    final distance = roundTrip
        ? config.route.distanceKmRoundTrip
        : config.route.distanceKmOneWay;

    final liters = litersNeeded(
      roundTrip: roundTrip,
      customConsumptionLPer100: customConsumptionLPer100,
    );

    final pricePerL = customFuelPricePerL ?? config.fuelPrices.blended();
    final fuel = liters * pricePerL;

    final tt = tolls(roundTrip: roundTrip, twoVignettes: twoVignettes);

    return CostBreakdown(
      roundTrip: roundTrip,
      twoVignettes: twoVignettes,
      distanceKm: distance,
      litersNeeded: liters,
      fuelPriceUsed: pricePerL,
      fuelCost: fuel,
      tollAustriaVignette: tt.austriaVignette,
      tollBrenner: tt.brenner,
      tollItaly: tt.italy,
    );
  }
}
