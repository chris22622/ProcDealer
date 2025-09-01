import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/supplier_provider.dart';
import '../../state/game_state.dart';

class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers = ref.watch(supplierProvider);
  final day = ref.watch(gameStateProvider.select((s) => s['day'] as int));
    return Scaffold(
      appBar: AppBar(title: const Text('Suppliers')),
      body: ListView.builder(
        itemCount: suppliers.length,
        itemBuilder: (_, i) {
          final s = suppliers[i];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => ref.read(supplierProvider.notifier).toggleContract(s.id, day: day),
                        child: Text(s.contracted ? 'Uncontract' : 'Contract'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Trust ${(s.trust * 100).toStringAsFixed(0)}% · Quality ${(s.quality * 100).toStringAsFixed(0)}% · Price x${s.priceMod.toStringAsFixed(2)}'),
                  if (s.contracted) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Text('Min/day:'),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 36,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove),
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  final cur = s.minDaily ?? 0;
                                  final next = (cur - 1).clamp(0, 999);
                                  ref.read(supplierProvider.notifier).setMinDaily(s.id, next, day: day);
                                },
                              ),
                              Text('${s.minDaily ?? 0}'),
                              IconButton(
                                icon: const Icon(Icons.add),
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  final cur = s.minDaily ?? 0;
                                  final next = (cur + 1).clamp(0, 999);
                                  ref.read(supplierProvider.notifier).setMinDaily(s.id, next, day: day);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Chip(label: Text('Until D${s.contractedUntilDay}')),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
