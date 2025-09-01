import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/game_state.dart';
import '../../state/crew_provider.dart';

class LabScreen extends ConsumerWidget {
  const LabScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gs = ref.watch(gameStateProvider);
  final metaRaw = gs['meta'];
  final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
    final purity = (meta['purityBoost'] ?? 0) as int;
    final adulterant = (meta['adulterantActive'] ?? false) as bool;
    final crew = ref.watch(crewProvider);
    final chemistBonus = crew.crew.any((c) => c.role == 'Chemist') ? 1 : 0;
    final maxPurity = 3 + chemistBonus;
  // Chemist effect on yield: best skill minus average fatigue
  final bestChem = crew.crew.where((c) => c.role == 'Chemist').fold<int>(0, (a, b) => a > b.skill ? a : b.skill);
  final chemList = crew.crew.where((c) => c.role == 'Chemist').toList();
  final avgFatigue = chemList.isEmpty ? 0.0 : chemList.map((c) => c.fatigue).reduce((a, b) => a + b) / chemList.length;
  final yieldMod = (1 + bestChem * 0.05 - avgFatigue * 0.01).clamp(0.5, 1.5);
  final cash = gs['cash'] as int;
  final capacity = ref.read(gameStateProvider.notifier).capacity();
  final held = ref.read(gameStateProvider.notifier).inventory.drugs.values.fold<int>(0, (a, b) => a + b);
  final room = (capacity - held).clamp(0, capacity);
  final costCtrl = TextEditingController(text: '200');
  final planCtrl = TextEditingController(text: '10');
    return Scaffold(
      appBar: AppBar(title: const Text('Lab')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Purity Recipe (+price, +brand over time)', style: Theme.of(context).textTheme.titleMedium),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: purity.toDouble(),
                    min: 0,
                    max: maxPurity.toDouble(),
                    divisions: maxPurity,
                    label: '$purity',
                    onChanged: (v) => ref.read(gameStateProvider.notifier).setPurityBoost(v.round()),
                  ),
                ),
                Text('$purity/${maxPurity}')
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Adulterant (short-term margin, hurts brand daily)'),
              value: adulterant,
              onChanged: (v) => ref.read(gameStateProvider.notifier).setAdulterantActive(v),
            ),
            const SizedBox(height: 12),
            const Text('Notes:'),
            const Text('• Purity increases price a bit and improves brand each day.'),
            const Text('• Adulterant increases margins but reduces brand each day.'),
            const Divider(height: 32),
            Text('Cook Meth (MVP)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Room left in stash: ${room} units'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: costCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Spend on precursors (\$)'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: planCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Planned units'))),
            ]),
            const SizedBox(height: 8),
            Builder(builder: (context) {
        final spend = int.tryParse(costCtrl.text) ?? 0;
              final planned = int.tryParse(planCtrl.text) ?? 0;
              final projUnits = (planned * yieldMod).round().clamp(0, room);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chemist yield mod: x${yieldMod.toStringAsFixed(2)} (skill ${bestChem}, fatigue ${avgFatigue.toStringAsFixed(0)})', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          if (projUnits > 0) Text('Projected output: ${projUnits} meth units for \$${spend}'),
                ],
              );
            }),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                final spend = int.tryParse(costCtrl.text) ?? 0;
                final planned = int.tryParse(planCtrl.text) ?? 0;
                if (spend <= 0 || planned <= 0) return;
                if (cash < spend) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not enough cash for precursors.')));
                  return;
                }
                final projUnits = (planned * yieldMod).round();
                ref.read(gameStateProvider.notifier).craftMeth(spend, projUnits);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cooked ${projUnits} units of meth.')));
              },
              icon: const Icon(Icons.local_fire_department),
              label: const Text('Cook Meth'),
            ),
          ],
        ),
      ),
    );
  }
}
