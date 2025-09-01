import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/game_state.dart';
import '../../data/drug_catalog.dart';

class VipContractsScreen extends ConsumerWidget {
  const VipContractsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gs = ref.watch(gameStateProvider);
    final day = (gs['day'] ?? 1) as int;
    final metaRaw = gs['meta'];
    final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
    final vipList = (meta['vipContracts'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? const <Map<String, dynamic>>[];
    final soldRaw = meta['soldTodayByDrug'];
    final soldByDrug = soldRaw is Map ? Map<String, dynamic>.from(soldRaw) : <String, dynamic>{};

    return Scaffold(
      appBar: AppBar(title: const Text('VIP Contracts')),
      body: vipList.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No VIP contracts yet.'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          final d = drugCatalog.first;
                          final next = [
                            ...vipList,
                            {
                              'drugId': d.id,
                              'minDaily': 5,
                              'priceBonus': 1.1,
                              'contractedUntilDay': day + 7,
                            }
                          ];
                          ref.read(gameStateProvider.notifier).setVipContracts(next);
                        },
                        child: const Text('Add 7d x5 basic'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          final d = drugCatalog[1 % drugCatalog.length];
                          final next = [
                            ...vipList,
                            {
                              'drugId': d.id,
                              'minDaily': 8,
                              'priceBonus': 1.15,
                              'contractedUntilDay': day + 5,
                            }
                          ];
                          ref.read(gameStateProvider.notifier).setVipContracts(next);
                        },
                        child: const Text('Add 5d x8 premium'),
                      ),
                    ],
                  )
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemBuilder: (_, i) {
                final v = vipList[i];
                final drugId = (v['drugId'] ?? '') as String;
                final d = drugCatalog.firstWhere((x) => x.id == drugId, orElse: () => drugCatalog.first);
                final until = (v['contractedUntilDay'] ?? 0) as int;
                final minDaily = (v['minDaily'] ?? 0) as int;
                final bonus = ((v['priceBonus'] ?? 1.0) as num).toDouble();
                final soldToday = (soldByDrug[drugId] ?? 0) as int;
                final daysLeft = (until - day).clamp(0, 9999);
                final active = day <= until;
                final miss = (minDaily - soldToday).clamp(0, minDaily);
                final penalty = miss > 0 ? (80 + 15 * miss) : 0;
                final pct = minDaily == 0 ? 1.0 : (soldToday / minDaily).clamp(0.0, 1.0);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber),
                            const SizedBox(width: 8),
                            Expanded(child: Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                            Chip(
                              label: Text(active ? 'Active (D$day / D$until)' : 'Expired'),
                              backgroundColor: active ? Colors.green.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Min/day: $minDaily • Today: $soldToday • Days left: $daysLeft'),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: pct,
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade800,
                          valueColor: AlwaysStoppedAnimation(pct >= 1.0 ? Colors.lightGreenAccent : Colors.orangeAccent),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text('Bonus: +${((bonus - 1) * 100).round()}%'),
                            const SizedBox(width: 16),
                            if (active)
                              Text('Penalty if unmet: \$${penalty}', style: const TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (!active)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                final next = [
                                  ...vipList.take(i),
                                  {
                                    ...v,
                                    'contractedUntilDay': day + 7,
                                  },
                                  ...vipList.skip(i + 1),
                                ];
                                ref.read(gameStateProvider.notifier).setVipContracts(next);
                              },
                              child: const Text('Renew 7 days'),
                            ),
                          )
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: vipList.length,
            ),
    );
  }
}
