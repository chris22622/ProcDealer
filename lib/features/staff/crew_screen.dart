import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/crew_provider.dart';
import '../../state/city_provider.dart';
import '../../state/game_state.dart';
import 'legal_screen.dart';

class CrewScreen extends ConsumerWidget {
  const CrewScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(crewProvider);
    final city = ref.watch(cityProvider);
    final metaRaw = ref.watch(gameStateProvider.select((s) => s['meta']));
    final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
    final currentDid = (meta['currentDistrictId'] ?? '') as String;
    return Scaffold(
      appBar: AppBar(title: const Text('Crew')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: st.crew.isEmpty
                    ? null
                    : () => ref.read(crewProvider.notifier).restAll(),
                icon: const Icon(Icons.bedtime),
                label: const Text('Rest all'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: st.crew.isEmpty
                    ? null
                    : () {
                        for (final m in st.crew) {
                          ref.read(crewProvider.notifier).assign(m.id, districtId: currentDid);
                        }
                      },
                icon: const Icon(Icons.place),
                label: const Text('Assign all to current'),
              ),
              const Spacer(),
              Builder(builder: (context) {
                final wagesDue = (meta['wagesDue'] ?? 0) as int;
                return Text('Wages today: \$${wagesDue}');
              })
            ],
          ),
          const SizedBox(height: 12),
          const Text('Hired', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ...((){
            final list = [...st.crew];
            list.sort((a,b){
              final aj = a.arrestedDays > 0 ? 1 : 0;
              final bj = b.arrestedDays > 0 ? 1 : 0;
              if (aj != bj) return aj.compareTo(bj);
              return a.role.compareTo(b.role);
            });
            return list;
          }()).map((m) => Opacity(
                opacity: m.arrestedDays > 0 ? 0.65 : 1.0,
                child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${m.role} (Skill ${m.skill}) • ${m.status.toUpperCase()}',
                                    style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 4),
                                Text('Wage \$${m.wage}/day · Today +\$${m.todayEarned} · Lifetime +\$${m.lifetimeEarned}'),
                                // Legal status badge
                                Builder(builder: (context) {
                                  final casesRaw = meta['legalCases'];
                                  final List<Map<String, dynamic>> cases = casesRaw is List
                                      ? casesRaw.map((e) => Map<String, dynamic>.from(e)).toList()
                                      : const <Map<String, dynamic>>[];
                                  Map<String, dynamic>? myCase;
                                  for (final c in cases) {
                                    if ((c['type'] ?? '') == 'crew' && (c['crewId'] ?? '') == m.id && (c['status'] ?? 'open') != 'resolved') {
                                      myCase = c; break;
                                    }
                                  }
                                  if ((m.arrestedDays <= 0) && myCase == null) return const SizedBox.shrink();
                                  String label;
                                  IconData icon;
                                  Color color;
                                  if (m.arrestedDays > 0) {
                                    label = 'In jail: ${m.arrestedDays}d remain';
                                    icon = Icons.lock;
                                    color = Colors.redAccent;
                                  } else {
                                    final days = (myCase?['daysUntilHearing'] ?? 0) as int;
                                    final status = (myCase?['status'] ?? 'open') as String;
                                    label = status == 'bailed' ? 'Bailed • Hearing in ${days}d' : 'Hearing in ${days}d';
                                    icon = Icons.gavel;
                                    color = Colors.amberAccent;
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Row(
                                      children: [
                                        Icon(icon, size: 18, color: color.withOpacity(0.9)),
                                        const SizedBox(width: 6),
                                        Flexible(child: Text(label)),
                                      ],
                                    ),
                                  );
                                }),
                                const SizedBox(height: 6),
                                LinearProgressIndicator(
                                  value: m.fatigue / 100.0,
                                  minHeight: 6,
                                  backgroundColor: Colors.grey.shade800,
                                  valueColor: const AlwaysStoppedAnimation(Colors.orangeAccent),
                                ),
                                const SizedBox(height: 4),
                                Text('Morale ${m.morale}')
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => ref.read(crewProvider.notifier).fire(m.id),
                                child: const Text('Fire'),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton(
                                onPressed: () => ref.read(crewProvider.notifier).train(m.id),
                                child: const Text('Train'),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.gavel, size: 16),
                                onPressed: () {
                                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalScreen()));
                                },
                                label: const Text('Legal'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // Use Wrap to avoid horizontal overflow and ensure responsive layout
                          final double halfWidth = constraints.maxWidth >= 480
                              ? (constraints.maxWidth / 2) - 6
                              : constraints.maxWidth;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              SizedBox(
                                width: halfWidth,
                                child: Builder(builder: (context) {
                                  // Deduplicate by district id to avoid duplicate DropdownMenuItem values
                                  final Map<String, dynamic> byId = {
                                    for (final d in city.districts) d.id: d,
                                  };
                                  final ids = byId.keys.toList(growable: false);
                                  String? selected =
                                      (m.assignedDistrictId?.isNotEmpty ?? false) ? m.assignedDistrictId : currentDid;
                                  if (selected == null || !ids.contains(selected)) {
                                    selected = ids.isNotEmpty ? ids.first : null;
                                  }
                                  return DropdownButtonFormField<String>(
                                    value: selected,
                                    decoration: const InputDecoration(labelText: 'Assigned District'),
                                    items: ids
                                        .map((id) => DropdownMenuItem<String>(value: id, child: Text(byId[id]!.name)))
                                        .toList(growable: false),
                                    onChanged: (val) {
                                      ref.read(crewProvider.notifier).assign(m.id, districtId: val);
                                    },
                                  );
                                }),
                              ),
                              SizedBox(
                                width: halfWidth,
                                child: DropdownButtonFormField<String>(
                                  value: m.strategy,
                                  decoration: const InputDecoration(labelText: 'Strategy'),
                                  items: const [
                                    DropdownMenuItem(value: 'balanced', child: Text('Balanced')),
                                    DropdownMenuItem(value: 'greedy', child: Text('Greedy')),
                                    DropdownMenuItem(value: 'lowrisk', child: Text('Low risk')),
                                  ],
                                  onChanged: (val) {
                                    ref.read(crewProvider.notifier).assign(m.id, strategy: val);
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ))),
          const SizedBox(height: 12),
          const Text('Candidates', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ...st.candidates.map((m) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${m.role} (Skill ${m.skill})',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text('Wage \$${m.wage}/day'),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: m.fatigue / 100.0,
                              minHeight: 6,
                              backgroundColor: Colors.grey.shade800,
                              valueColor: const AlwaysStoppedAnimation(Colors.orangeAccent),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => ref.read(crewProvider.notifier).hire(m.id),
                        child: const Text('Hire'),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
