import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/types.dart';
import '../core/rng.dart';
import 'game_state.dart';

class FactionController extends StateNotifier<List<Faction>> {
  final Ref _ref;
  FactionController(this._ref, List<Faction> initial) : super(initial);
  void adjustRep(String factionId, int delta) {
    state = state
        .map((f) => f.id == factionId ? f.copyWith(reputation: (f.reputation + delta).clamp(-100, 100)) : f)
        .toList();
    _ref.read(gameStateProvider.notifier).setFactions(state);
  }

  void truce(String factionId) {
    // small immediate rep bump
    adjustRep(factionId, 5);
  }

  void tribute(String factionId, int amount) {
    // tribute gives a better rep bump; caller handles cash/heat
    final bump = (amount / 50).round().clamp(2, 10);
    adjustRep(factionId, bump);
  }
}

final factionProvider = StateNotifierProvider<FactionController, List<Faction>>((ref) {
  final metaRaw = ref.watch(gameStateProvider.select((s) => s['meta']));
  final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
  final saved = meta['factions'] as List<dynamic>?;
  if (saved != null && saved.isNotEmpty) {
    final list = saved.map((j) => Faction.fromJson(Map<String, dynamic>.from(j))).toList();
    return FactionController(ref, list);
  }
  // seed if none saved
  final day = ref.read(gameStateProvider.select((s) => s['day'] as int));
  final rng = Rng(day * 12347);
  final names = ['Kings Row', 'Harbor Pack', 'Neon Crew'];
  final list = List.generate(names.length, (i) => Faction(
        id: 'fac$i',
        name: names[i],
        reputation: (rng.nextDoubleRange(-1, 1) * 40).round(),
      ));
  // Defer persistence to outside the provider build to avoid re-entrancy
  Future.microtask(() => ref.read(gameStateProvider.notifier).setFactions(list));
  return FactionController(ref, list);
});
