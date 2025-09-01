import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/rng.dart';
import '../core/balance.dart';
import '../core/types.dart';
import '../data/district_templates.dart';
import 'game_state.dart';
import 'faction_provider.dart';

class CityGraph {
  final List<District> districts;
  final List<Edge> edges;
  // Optional per-district passive bonuses (applied externally)
  final Map<String, Map<String, num>> bonuses; // districtId -> {key: value}
  CityGraph({required this.districts, required this.edges, this.bonuses = const {}});
}

int shortestHops(CityGraph city, int fromIndex, int toIndex) {
  if (fromIndex == toIndex) return 0;
  if (fromIndex < 0 || toIndex < 0 || fromIndex >= city.districts.length || toIndex >= city.districts.length) {
    return -1;
  }
  // Build adjacency list by index
  final idToIndex = <String, int>{
    for (int i = 0; i < city.districts.length; i++) city.districts[i].id: i,
  };
  final adj = List.generate(city.districts.length, (_) => <int>[]);
  for (final e in city.edges) {
    if (e.blocked) continue;
    final i = idToIndex[e.from];
    final j = idToIndex[e.to];
    if (i != null && j != null) {
      adj[i].add(j);
      adj[j].add(i);
    }
  }
  final visited = List.filled(city.districts.length, false);
  final queue = <int>[];
  final dist = List.filled(city.districts.length, -1);
  visited[fromIndex] = true;
  dist[fromIndex] = 0;
  queue.add(fromIndex);
  while (queue.isNotEmpty) {
    final cur = queue.removeAt(0);
    if (cur == toIndex) return dist[cur];
    for (final nb in adj[cur]) {
      if (!visited[nb]) {
        visited[nb] = true;
        dist[nb] = dist[cur] + 1;
        queue.add(nb);
      }
    }
  }
  return -1; // unreachable
}

CityGraph generateCity(int seed, List<Faction> factions) {
  final rng = Rng(seed);
  final n = rng.nextIntRange(Balance.minDistricts, Balance.maxDistricts);
  // Deterministic shuffle based on the seeded RNG to keep city stable per day
  List<Map<String, dynamic>> deterministicShuffle(List<Map<String, dynamic>> src, Rng rng) {
    final a = List<Map<String, dynamic>>.from(src);
    for (int i = a.length - 1; i > 0; i--) {
      final j = rng.nextIntRange(0, i);
      final t = a[i];
      a[i] = a[j];
      a[j] = t;
    }
    return a;
  }
  final templates = deterministicShuffle(districtTemplates, rng);
  final districts = List.generate(n, (i) {
    final base = District.fromJson(templates[i % templates.length]);
    if (factions.isNotEmpty) {
      final f = factions[rng.nextIntRange(0, factions.length - 1)];
      return base.copyWith(factionId: f.id);
    }
    return base;
  });
  final edges = <Edge>[];
  for (int i = 0; i < n; i++) {
    for (int j = i + 1; j < n; j++) {
      if (rng.nextDoubleRange(0, 1) < 0.5) {
        edges.add(Edge(from: districts[i].id, to: districts[j].id, blocked: false));
      }
    }
  }
  // Seed simple bonuses by wealth/policePresence
  final bonuses = <String, Map<String, num>>{};
  for (final d in districts) {
    final priceBonus = (d.wealth >= 70) ? -0.05 : (d.wealth <= 30 ? 0.05 : 0.0);
    final corruption = rng.nextDoubleRange(0.1, 0.9); // 0..1 how corrupt local officials are
    final heatDecay = (d.policePresence <= 0.3) ? 0.05 : 0.0;
    final storage = (d.prosperity >= 0.7) ? 25 : 0; // extra capacity in rich areas
    bonuses[d.id] = {
      if (priceBonus != 0) 'priceMod': priceBonus,
      if (heatDecay != 0) 'heatDecayBonus': heatDecay,
      if (storage != 0) 'storageBonus': storage,
      'corruption': corruption,
    };
  }
  return CityGraph(districts: districts, edges: edges, bonuses: bonuses);
}

final cityProvider = Provider<CityGraph>((ref) {
  final day = ref.watch(gameStateProvider.select((s) => s['day'] as int));
  final factions = ref.watch(factionProvider);
  final city = generateCity(day, factions);
  // If no home/current district has been set yet, pick a random one now and persist.
  try {
    final metaRaw = ref.read(gameStateProvider.select((s) => s['meta']));
    final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
    final hasHome = ((meta['homeDistrictId'] ?? '') as String).isNotEmpty;
    final curId = ((meta['currentDistrictId'] ?? '') as String);
    // Align currentDistrict index with id in case day change regenerated city ids in a different order
    if (curId.isNotEmpty) {
      final idx = city.districts.indexWhere((d) => d.id == curId);
      if (idx >= 0 && idx != (meta['currentDistrict'] ?? -1)) {
        final bonus = city.bonuses[curId] ?? const {};
        Future.microtask(() => ref.read(gameStateProvider.notifier).setCurrentDistrictContext(
              index: idx,
              id: curId,
              heatDecayBonus: (bonus['heatDecayBonus'] as dynamic)?.toDouble(),
              storageBonus: (bonus['storageBonus'] as dynamic)?.toInt(),
            ));
      }
    }
    if (!hasHome && city.districts.isNotEmpty) {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final idx = ts.remainder(city.districts.length).clamp(0, city.districts.length - 1);
      final did = city.districts[idx].id;
      final bonus = city.bonuses[did] ?? const {};
  Future.microtask(() => ref.read(gameStateProvider.notifier).setHomeDistrict(
    index: idx,
    id: did,
    heatDecayBonus: (bonus['heatDecayBonus'] as dynamic)?.toDouble(),
    storageBonus: (bonus['storageBonus'] as dynamic)?.toInt(),
      ));
    }
  } catch (_) {}
  return city;
});
