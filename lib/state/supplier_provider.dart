import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/types.dart';
import '../core/rng.dart';
import 'game_state.dart';

class SupplierList extends StateNotifier<List<Supplier>> {
  final Ref ref;
  SupplierList(this.ref, List<Supplier> initial) : super(initial);
  void toggleContract(String id, {required int day}) {
    final updated = [
      for (final s in state)
        if (s.id == id)
          s.copyWith(
            contracted: !s.contracted,
            minDaily: !s.contracted ? 5 : null, // require 5 units/day when turning on
            contractedUntilDay: !s.contracted ? day + 7 : null, // 1-week term
          )
        else
          s
    ];
    state = updated;
    // persist to game meta
    final contracts = updated
        .where((s) => s.contracted)
        .map((s) => {
              'id': s.id,
              'contracted': s.contracted,
              'minDaily': s.minDaily,
              'contractedUntilDay': s.contractedUntilDay,
            })
        .toList();
    ref.read(gameStateProvider.notifier).setContractsJson(contracts);
  }

  void setMinDaily(String id, int? minDaily, {required int day}) {
    final updated = [
      for (final s in state)
        if (s.id == id)
          s.copyWith(
            minDaily: minDaily,
          )
        else
          s
    ];
    state = updated;
    final contracts = updated
        .where((s) => s.contracted)
        .map((s) => {
              'id': s.id,
              'contracted': s.contracted,
              'minDaily': s.minDaily,
              'contractedUntilDay': s.contractedUntilDay,
            })
        .toList();
    ref.read(gameStateProvider.notifier).setContractsJson(contracts);
  }
}

final StateNotifierProvider<SupplierList, List<Supplier>> supplierProvider = StateNotifierProvider<SupplierList, List<Supplier>>((ref) {
  final day = ref.watch(gameStateProvider.select((s) => s['day'] as int));
  // hydrate from meta contracts if present
  final metaRaw = ref.watch(gameStateProvider.select((s) => s['meta']));
  final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
  final contractsRaw = meta['contracts'];
  final trustRaw = meta['supplierTrustById'];
  final trustById = trustRaw is Map
      ? Map<String, double>.from(trustRaw.map((k, v) => MapEntry(k.toString(), ((v as num).toDouble()).clamp(0.0, 1.0))))
      : <String, double>{};
  final rng = Rng(day * 7919);
  final items = List.generate(4, (i) {
    return Supplier(
      id: 'sup$i',
      name: 'Supplier #${i + 1}',
      trust: rng.nextDoubleRange(0.2, 0.9),
      quality: rng.nextDoubleRange(0.3, 1.0),
      priceMod: rng.nextDoubleRange(0.8, 1.2),
    );
  });
  // Apply persisted contracts state
  if (contractsRaw is List && contractsRaw.isNotEmpty) {
    final list = contractsRaw.map((e) => Map<String, dynamic>.from(e)).toList();
    for (int i = 0; i < items.length; i++) {
      final match = list.firstWhere(
        (c) => c['id'] == items[i].id,
        orElse: () => <String, dynamic>{},
      );
      if (match.isNotEmpty) {
        items[i] = items[i].copyWith(
          contracted: (match['contracted'] ?? false) as bool,
          minDaily: match['minDaily'] as int?,
          contractedUntilDay: match['contractedUntilDay'] as int?,
        );
      }
    }
  }
  // Override trust if we have persisted values
  if (trustById.isNotEmpty) {
    for (int i = 0; i < items.length; i++) {
      final t = trustById[items[i].id];
      if (t != null) {
        items[i] = Supplier(
          id: items[i].id,
          name: items[i].name,
          trust: t,
          quality: items[i].quality,
          priceMod: items[i].priceMod,
          contracted: items[i].contracted,
          minDaily: items[i].minDaily,
          contractedUntilDay: items[i].contractedUntilDay,
        );
      }
    }
  }
  return SupplierList(ref, items);
});
