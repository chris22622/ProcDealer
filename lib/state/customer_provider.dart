import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/rng.dart';
import '../core/types.dart';
import '../data/drug_catalog.dart';
import 'game_state.dart';
import 'market_provider.dart';

class CustomerFactory {
  // Generate offers varying by day and district, with light weighting to inventory holdings.
  static List<Offer> generateOffers({required int day, required int districtIndex, required Map<String, int> holdings, required List<Map<String, dynamic>> prices, Map<String, double>? loyalty, Map<String, dynamic>? meta}) {
    final rng = Rng(day * 1009 + districtIndex * 7919);
    final offers = <Offer>[];
    final types = ['Loyal', 'Whale', 'Sketchy'];
    final baseWeights = [0.5, 0.3, 0.2];
    final weights = [
      (baseWeights[0] * (loyalty?['Loyal'] ?? 1.0)).clamp(0.1, 2.0),
      (baseWeights[1] * (loyalty?['Whale'] ?? 1.0)).clamp(0.1, 2.0),
      (baseWeights[2] * (loyalty?['Sketchy'] ?? 1.0)).clamp(0.1, 2.0),
    ];

    // Build a quick lookup for current market unit prices
    final priceById = <String, int>{
      for (final row in prices) (row['drug'] as Drug).id: row['price'] as int,
    };

    // Slightly weight the catalog pick by rarity and what you hold
    List<double> drugWeights = drugCatalog.map((d) => d.rarity).toList();
    for (int i = 0; i < drugCatalog.length; i++) {
      final d = drugCatalog[i];
      final have = holdings[d.id] ?? 0;
      if (have > 0) drugWeights[i] *= 1.5; // bias towards your stash
    }

  final n = rng.nextIntRange(4, 7);
    for (int i = 0; i < n; i++) {
  final drug = rng.pickWeighted(drugCatalog, drugWeights);
      final qty = rng.nextIntRange(drug.volMin, drug.volMax);
  final type = rng.pickWeighted(types, weights);
      double risk = 0.1;
      // Start from market unit price if available, fallback to basePrice
      final unitBase = priceById[drug.id] ?? drug.basePrice;
      int price = unitBase;
      switch (type) {
        case 'Loyal':
          risk = 0.05;
          price = (unitBase * rng.nextDoubleRange(0.9, 1.08)).round();
          break;
        case 'Whale':
          risk = 0.15;
          price = (unitBase * rng.nextDoubleRange(1.0, 1.25)).round();
          break;
        case 'Sketchy':
          risk = 0.3;
          price = (unitBase * rng.nextDoubleRange(1.05, 1.35)).round();
          break;
      }
      offers.add(Offer(drugId: drug.id, qty: qty, priceOffer: price, customerType: type, risk: risk));
    }

    // Guarantee at least one buyer for your top-held drug
    final top = holdings.entries.where((e) => (e.value) > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (top.isNotEmpty) {
      final topDrugId = top.first.key;
      final already = offers.any((o) => o.drugId == topDrugId);
      if (!already) {
        final d = drugCatalog.firstWhere((x) => x.id == topDrugId);
        final unitBase = priceById[topDrugId] ?? d.basePrice;
        final qty = rng.nextIntRange(1, top.first.value);
        final type = rng.pickWeighted(types, weights);
        final price = (unitBase * rng.nextDoubleRange(1.0, 1.2)).round();
        offers.add(Offer(drugId: d.id, qty: qty, priceOffer: price, customerType: type, risk: type == 'Sketchy' ? 0.25 : 0.12));
      }
    }

    // Occasionally generate a VIP contract style offer subject to contract routing constraints
    if (rng.nextDoubleRange(0, 1) < 0.2) {
      final d = rng.pickWeighted(drugCatalog, drugWeights);
      final unitBase = priceById[d.id] ?? d.basePrice;
      final qty = rng.nextIntRange(d.volMax, d.volMax * 2);
      final price = (unitBase * 1.3).round();
      bool eligible = true;
      try {
        final vipList = (meta?['vipContracts'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? const <Map<String, dynamic>>[];
        final match = vipList.firstWhere(
          (v) => (v['drugId'] ?? '') == d.id && (v['contractedUntilDay'] ?? 0) >= day,
          orElse: () => const {},
        );
        if (match.isNotEmpty) {
          final restrictId = (match['restrictDistrictId'] ?? '') as String?;
          if (restrictId != null && restrictId.isNotEmpty) {
            // require current districtId to match
            final curId = (meta?['currentDistrictId'] ?? '') as String?;
            if (curId == null || curId != restrictId) eligible = false;
          }
          final window = (match['window'] ?? '') as String?; // e.g., 'Night' or 'Day'
          if (window != null && window.isNotEmpty) {
            final curPart = (meta?['dayPart'] ?? 'Day') as String;
            if (window != curPart) eligible = false;
          }
        }
      } catch (_) {}
      if (eligible) {
        offers.add(Offer(drugId: d.id, qty: qty, priceOffer: price, customerType: 'VIP', risk: 0.08));
      } else {
        // fallback: offer as Whale instead (no VIP bonus)
        final whalePrice = (unitBase * rng.nextDoubleRange(1.05, 1.2)).round();
        offers.add(Offer(drugId: d.id, qty: qty, priceOffer: whalePrice, customerType: 'Whale', risk: 0.15));
      }
    }

    return offers;
  }
}

final customerProvider = Provider<List<Offer>>((ref) {
  final day = ref.watch(gameStateProvider.select((s) => s['day'] as int));
  final metaRaw = ref.watch(gameStateProvider.select((s) => s['meta']));
  final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
  final invRaw = ref.watch(gameStateProvider.select((s) => s['inventory']));
  final invMap = invRaw is Map ? Map<String, dynamic>.from(invRaw) : <String, dynamic>{};
  final holdings = Inventory.fromJson(invMap).drugs;
  final district = (meta['currentDistrict'] ?? 0) as int;
  final loyaltyRaw = meta['loyalty'];
  final loyalty = loyaltyRaw is Map
      ? loyaltyRaw.map((k, v) => MapEntry(k.toString(), ((v as num).toDouble())))
      : <String, double>{};
  // Get current market prices for context (brand/economy/suppliers/factions already applied)
  final prices = ref.watch(marketProvider);
  try {
  return CustomerFactory.generateOffers(day: day, districtIndex: district, holdings: holdings, prices: prices, loyalty: loyalty, meta: meta);
  } catch (_) {
    return const <Offer>[];
  }
});
