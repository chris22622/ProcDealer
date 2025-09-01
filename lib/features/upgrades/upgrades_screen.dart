import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/upgrade_provider.dart';
import '../production/lab_screen.dart';
import '../../state/game_state.dart';

class UpgradesScreen extends ConsumerWidget {
  const UpgradesScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upgrades = ref.watch(upgradeProvider);
    final upNotifier = ref.read(upgradeProvider.notifier);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Upgrades', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LabScreen())),
          icon: const Icon(Icons.science),
          label: const Text('Open Lab'),
        ),
        _upgradeCard(context, ref, key: 'vehicle', name: 'Vehicle', level: upgrades.vehicle, max: upNotifier.maxLevel('vehicle'),
          description: 'Better transport lowers travel cost and heat from moving between districts.',
          currentEffect: '-${(upgrades.vehicle * 12).clamp(0, 99)}% travel cost, -${(upgrades.vehicle * 6).clamp(0, 99)}% travel heat',
        ),
        _upgradeCard(context, ref, key: 'safehouse', name: 'Safehouse', level: upgrades.safehouse, max: upNotifier.maxLevel('safehouse'),
          description: 'Increase stash capacity and reduce bust chance a bit.',
          currentEffect: '+${upgrades.safehouse * 50} capacity, -${(upgrades.safehouse * 5).clamp(0, 99)}% bust chance',
        ),
        _upgradeCard(context, ref, key: 'burner', name: 'Burner', level: upgrades.burner, max: upNotifier.maxLevel('burner'),
          description: 'Disposable phones and comms reduce evidence growth from sales.',
          currentEffect: '-${(upgrades.burner * 12).clamp(0, 99)}% evidence growth',
        ),
        _upgradeCard(context, ref, key: 'scanner', name: 'Scanner', level: upgrades.scanner, max: upNotifier.maxLevel('scanner'),
          description: 'Police scanner lowers police pressure and general bust risk.',
          currentEffect: '-${(upgrades.scanner * 4).clamp(0, 99)}% police pressure, -${(upgrades.scanner * 10).clamp(0, 99)}% bust chance',
        ),
        _upgradeCard(context, ref, key: 'laundromat', name: 'Laundromat', level: upgrades.laundromat, max: upNotifier.maxLevel('laundromat'),
          description: 'One-time business that adds passive daily income.',
          currentEffect: upgrades.laundromat > 0 ? '+\$250 cash per day' : 'Locked',
        ),
      ],
    );
  }

  Widget _upgradeCard(BuildContext context, WidgetRef ref, {required String key, required String name, required int level, required int max, required String description, required String currentEffect}) {
  final gs = ref.watch(gameStateProvider);
    final cash = (gs['cash'] as int);
    final notifier = ref.read(upgradeProvider.notifier);
    final nextCost = notifier.nextCost(key);
    final canBuy = nextCost != null && cash >= nextCost && level < max;
    String? nextEffect;
    if (level < max) {
      final nl = level + 1;
      switch (key) {
        case 'vehicle':
          nextEffect = '-${(nl * 12).clamp(0, 99)}% travel cost, -${(nl * 6).clamp(0, 99)}% travel heat';
          break;
        case 'safehouse':
          nextEffect = '+${nl * 50} capacity, -${(nl * 5).clamp(0, 99)}% bust chance';
          break;
        case 'burner':
          nextEffect = '-${(nl * 12).clamp(0, 99)}% evidence growth';
          break;
        case 'scanner':
          nextEffect = '-${(nl * 4).clamp(0, 99)}% police pressure, -${(nl * 10).clamp(0, 99)}% bust chance';
          break;
        case 'laundromat':
          nextEffect = '+\$250 cash per day';
          break;
      }
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _levelDots(level, max),
                const SizedBox(width: 8),
                Expanded(child: Text('$name (Level $level/$max)', style: Theme.of(context).textTheme.titleMedium)),
        if (nextCost != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
          child: Text('Next: \$${nextCost}')
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Maxed')
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 4),
            Text('Current effect: $currentEffect', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
            if (nextEffect != null) ...[
              const SizedBox(height: 4),
              Text('Next level: $nextEffect', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: canBuy ? () => ref.read(upgradeProvider.notifier).purchase(key) : null,
                child: Text(level < max ? 'Buy' : 'Maxed'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _levelDots(int level, int max) {
    return Row(
      children: List.generate(max, (i) {
        final filled = i < level;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            Icons.circle,
            size: 10,
            color: filled ? Colors.tealAccent : Colors.white24,
          ),
        );
      }),
    );
  }

}
