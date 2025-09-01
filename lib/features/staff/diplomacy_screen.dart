import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/faction_provider.dart';
import '../../state/city_provider.dart';
import '../../state/game_state.dart';

class DiplomacyScreen extends ConsumerWidget {
  const DiplomacyScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final factions = ref.watch(factionProvider);
    final city = ref.watch(cityProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Factions')),
      body: ListView.builder(
        itemCount: factions.length,
        itemBuilder: (_, i) {
          final f = factions[i];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(f.name, style: Theme.of(context).textTheme.titleMedium)),
                      Chip(label: Text('Rep ${f.reputation}')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.flag),
                        label: const Text('Truce'),
                        onPressed: () => ref.read(factionProvider.notifier).truce(f.id),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.volunteer_activism),
                        label: const Text('Tribute \$50'),
                        onPressed: () {
                          ref.read(gameStateProvider.notifier).spendCash(50);
                          ref.read(factionProvider.notifier).tribute(f.id, 50);
                        },
                      ),
                      PopupMenuButton<String>(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.shield),
                          label: const Text('Buy protection'),
                          onPressed: null,
                        ),
                        onSelected: (did) => _showProtectionSheet(context, ref, did),
                        itemBuilder: (_) => [
                          for (final d in city.districts)
                            PopupMenuItem<String>(value: d.id, child: Text('In ${d.name}')),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

void _showProtectionSheet(BuildContext context, WidgetRef ref, String districtId) {
  final gs = ref.read(gameStateProvider);
  final cash = (gs['cash'] ?? 0) as int;
  int days = 3;
  const int costPerDay = 50;
  showModalBottomSheet(
    context: context,
    builder: (_) {
      return StatefulBuilder(builder: (context, setState) {
        final cost = days * costPerDay;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Buy protection', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Days: $days  •  Cost/day: \$$costPerDay  •  Total: \$$cost'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final d in [3, 7, 14])
                    OutlinedButton(
                      onPressed: () => setState(() => days = d),
                      child: Text('${d}d'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: cash >= cost
                      ? () {
                          ref.read(gameStateProvider.notifier).buyProtection(districtId, days, costPerDay: costPerDay);
                          Navigator.of(context).pop();
                        }
                      : null,
                  icon: const Icon(Icons.shield),
                  label: const Text('Confirm'),
                ),
              )
            ],
          ),
        );
      });
    },
  );
}
