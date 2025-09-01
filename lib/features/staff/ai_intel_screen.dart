import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/game_state.dart';
import '../../state/city_provider.dart';

class AiIntelScreen extends ConsumerWidget {
  const AiIntelScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaRaw = ref.watch(gameStateProvider.select((s) => s['meta']));
    final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
  final city = ref.watch(cityProvider);
  final idToName = {for (final d in city.districts) d.id: d.name};
    final aiListRaw = meta['aiOpponents'];
    final List<Map<String, dynamic>> aiList = aiListRaw is List
        ? aiListRaw.map((e) => Map<String, dynamic>.from(e)).toList()
        : const <Map<String, dynamic>>[];
    final String difficulty = (meta['aiDifficulty'] ?? 'normal') as String;
    final pressRaw = meta['policePressureByDid'];
    final Map<String, int> pressure = pressRaw is Map
        ? Map<String, int>.from(pressRaw.map((k, v) => MapEntry(k.toString(), (v as num).toInt())))
        : <String, int>{};
  final shieldsRaw = meta['supplierShieldById'];
  final Map<String, int> shields = shieldsRaw is Map
    ? Map<String, int>.from(shieldsRaw.map((k, v) => MapEntry(k.toString(), (v as num).toInt())))
    : <String, int>{};
    return Scaffold(
      appBar: AppBar(title: const Text('AI Intel')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Difficulty: '),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: difficulty,
                  items: const [
                    DropdownMenuItem(value: 'easy', child: Text('Easy')),
                    DropdownMenuItem(value: 'normal', child: Text('Normal')),
                    DropdownMenuItem(value: 'hard', child: Text('Hard')),
                  ],
                  onChanged: (v) {
                    if (v != null) ref.read(gameStateProvider.notifier).setAiDifficulty(v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Rivals', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (aiList.isEmpty) const Text('No known rivals yet.'),
            ...aiList.map((ai) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.ssid_chart),
                    title: Text(ai['name'] ?? ai['id'] ?? 'Rival'),
                    subtitle: Text('Personality: ${ai['personality'] ?? 'aggressive'} · Budget: ${ai['budget'] ?? 0}'),
                  ),
                )),
            const SizedBox(height: 16),
            const Text('Active Police Pressure', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (pressure.isEmpty) const Text('None'),
            ...pressure.entries.map((e) => ListTile(
                  leading: const Icon(Icons.local_police, color: Colors.redAccent),
      title: Text(idToName[e.key] ?? e.key),
                  subtitle: Text('${e.value} days remaining'),
                  trailing: ElevatedButton(
                    onPressed: () => ref.read(gameStateProvider.notifier).coolDistrictPolice(e.key, daysRemove: 1),
                    child: const Text('Cool (-\$40)'),
                  ),
                )),
            const Divider(),
    const Text('Supplier Security', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
    if (shields.isEmpty) const Text('No active shields'),
    ...shields.entries.map((e) => ListTile(
      leading: const Icon(Icons.shield, color: Colors.blueAccent),
      title: Text('Supplier ${e.key}'),
      subtitle: Text('${e.value} days remaining'),
        )),
            _SecureSupplierRow(),
          ],
        ),
      ),
    );
  }
}

class _SecureSupplierRow extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SecureSupplierRow> createState() => _SecureSupplierRowState();
}

class _SecureSupplierRowState extends ConsumerState<_SecureSupplierRow> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
  const Expanded(child: Text('Enter Supplier ID to secure for 3 days (-\$120)')),
        SizedBox(
          width: 160,
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(hintText: 'supplier_id'),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            final id = _controller.text.trim();
            if (id.isNotEmpty) ref.read(gameStateProvider.notifier).secureSupplier(id);
          },
          child: const Text('Secure'),
        ),
      ],
    );
  }
}
