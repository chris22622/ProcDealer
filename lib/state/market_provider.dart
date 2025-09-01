import '../core/rng.dart';
import '../core/balance.dart';
import '../data/drug_catalog.dart';
import 'game_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'event_provider.dart';
import 'supplier_provider.dart';
import 'economy_provider.dart';
import 'faction_provider.dart';
import 'city_provider.dart';
import 'crew_provider.dart';

final marketProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final day = ref.watch(gameStateProvider.select((s) => s['day'] as int));
  final rng = Rng(day);
  final events = ref.watch(eventProvider);
  final eco = ref.watch(economyProvider);
  final scarcity = <String, double>{};
  for (final e in events) {
    if (e.type == 'Drought' && e.drugId != null) {
      scarcity[e.drugId!] = (scarcity[e.drugId!] ?? 1.0) * 1.25; // +25%
    }
  }
  // Global shortages (multi-day), stored in meta
  final metaRaw = ref.watch(gameStateProvider.select((s) => s['meta']));
  final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
  final globalShortages = (meta['globalShortages'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? const <Map<String, dynamic>>[];
  for (final g in globalShortages) {
    final drugId = g['drugId'] as String?;
    final until = (g['untilDay'] ?? 0) as int;
    if (drugId != null && day <= until) {
      scarcity[drugId] = (scarcity[drugId] ?? 1.0) * 1.15;
    }
  }
  final suppliers = ref.watch(supplierProvider);
  final contractMod = suppliers.where((s) => s.contracted).fold<double>(1.0, (m, s) => m * s.priceMod);
  final factions = ref.watch(factionProvider);
  final avgRep = factions.isEmpty ? 0.0 : factions.map((f) => f.reputation).reduce((a, b) => a + b) / factions.length;
  final factionPriceMod = 1 + (-avgRep / 5000.0); // bad rep => slightly higher prices
  // reuse meta var
  final brandRep = (meta['brandRep'] ?? 50) as int;
  final purityBoost = (meta['purityBoost'] ?? 0) as int; // 0..3
  final brandMod = 1 + ((brandRep - 50) / 1000); // +/-5% at extremes
  final purityMod = 1 + (purityBoost * 0.03); // up to +9%
  // District price bonus
  final city = ref.watch(cityProvider);
  final idx = (meta['currentDistrict'] ?? 0) as int;
  final districtId = (idx >= 0 && idx < city.districts.length) ? city.districts[idx].id : null;
  final dBonus = (districtId != null) ? (city.bonuses[districtId]?['priceMod'] ?? 0).toDouble() : 0.0;
  // Chemist bonus: increases unit prices slightly based on best chemist skill minus fatigue
  double chemistMod = 1.0;
  try {
    final crew = ref.watch(crewProvider);
    final bestChem = crew.crew.where((c) => c.role == 'Chemist').fold<int>(0, (a, b) => a > b.skill ? a : b.skill);
    final avgFatigue = crew.crew.where((c) => c.role == 'Chemist').fold<int>(0, (a, b) => a + b.fatigue);
    final count = crew.crew.where((c) => c.role == 'Chemist').length;
    final fatiguePenalty = count == 0 ? 0 : (avgFatigue / count) / 100.0; // 0..1
    chemistMod = (1 + bestChem * 0.01 - fatiguePenalty * 0.03).clamp(0.95, 1.08);
  } catch (_) {}
  return drugCatalog.map((drug) {
    final volatility = Balance.volCap * (rng.nextDoubleRange(-1, 1));
    final scarcityMod = scarcity[drug.id] ?? 1.0;
    double base = drug.basePrice * (1 + volatility) * scarcityMod * eco.priceMod() * brandMod * purityMod * factionPriceMod * (1 + dBonus) * chemistMod;
    // Weekly mutation modifier (e.g., +risk week or +cost week)
    final mut = meta['mutationOfWeek'];
    if (mut is Map) {
      final typ = mut['type'];
      if (typ == 'ExpensiveWeek') base *= 1.05;
      if (typ == 'ScarceWeek') base *= 1.08;
    }
    // Diminishing elasticity: cap margins by bending price back toward base when very high
    final margin = base / drug.basePrice; // ~1.x
    if (margin > 1.5) {
      base = drug.basePrice * (1.5 + (margin - 1.5) * 0.4);
    }
    final price = (base * contractMod).round();
    return {
      'drug': drug,
      'price': price,
    };
  }).toList();
});
