import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/types.dart';
import '../../state/game_state.dart';
import '../../state/crew_provider.dart';
import '../../state/faction_provider.dart';
import '../../state/city_provider.dart';

class DistrictDetailDialog extends ConsumerWidget {
  final District district;
  final int index;
  const DistrictDetailDialog({Key? key, required this.district, required this.index}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gs = ref.watch(gameStateProvider);
    final crew = ref.watch(crewProvider);
    final factions = ref.watch(factionProvider);
  final controllingFaction = district.factionId == null
    ? null
    : (factions.where((f) => f.id == district.factionId).isEmpty ? null : factions.firstWhere((f) => f.id == district.factionId));
  final inflRaw = (gs['meta']['influenceByDistrict'] ?? const <String, int>{});
  final protRaw = (gs['meta']['protectionByDistrict'] ?? const <String, int>{});
  final influence = inflRaw is Map ? (inflRaw[district.id] ?? 0) as int : 0;
  final protectionDays = protRaw is Map ? (protRaw[district.id] ?? 0) as int : 0;
  return AlertDialog(
      title: Text(district.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.attach_money, color: Colors.greenAccent),
              const SizedBox(width: 8),
              Text('Wealth: ${district.wealth}')
            ],
          ),
          Row(
            children: [
              Icon(Icons.shield, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Text('Police: ${(district.policePresence * 100).toStringAsFixed(0)}%')
            ],
          ),
          Row(
            children: [
              Icon(Icons.trending_up, color: Colors.orangeAccent),
              const SizedBox(width: 8),
              Text('Prosperity: ${(district.prosperity * 100).toStringAsFixed(0)}%')
            ],
          ),
          if (controllingFaction != null)
            Row(
              children: [
                Icon(Icons.flag, color: Colors.purpleAccent),
                const SizedBox(width: 8),
                Text('Controlled by: ${controllingFaction.name} (rep ${controllingFaction.reputation})')
              ],
            ),
          if (controllingFaction != null)
            Builder(builder: (_) {
              final rep = controllingFaction.reputation;
              final rate = (0.05 - (rep / 2000.0)).clamp(0.02, 0.07);
              return Row(
                children: [
                  Icon(Icons.percent, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Text('Tribute on sales: ${(rate * 100).toStringAsFixed(1)}%')
                ],
              );
            }),
          Row(
            children: [
              const Icon(Icons.track_changes, color: Colors.cyanAccent),
              const SizedBox(width: 8),
              Text('Influence: ${influence}%')
            ],
          ),
          if (protectionDays > 0)
            Row(
              children: [
                const Icon(Icons.shield_moon, color: Colors.tealAccent),
                const SizedBox(width: 8),
                Text('Protection active: ${protectionDays}d')
              ],
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            // travel cost and heat by shortest-path hops, vehicle upgrade, and driver skill
            final vehicle = (gs['upgrades']['vehicle'] ?? 0) as int;
            final driverSkill = crew.crew.where((c) => c.role == 'Driver').map((c) => c.skill).fold<int>(0, (a, b) => a > b ? a : b);
            final driverFatigueAvg = () {
              final list = crew.crew.where((c) => c.role == 'Driver').toList();
              if (list.isEmpty) return 0.0;
              return list.map((c) => c.fatigue).reduce((a, b) => a + b) / list.length;
            }();
            final current = (gs['meta']['currentDistrict'] ?? 0) as int;
            // compute hops via city graph
            final city = ref.read(cityProvider);
            final hops = shortestHops(city, current, index);
            final hopFactor = (hops <= 0 ? 1.0 : 1.0 + 0.5 * hops);
            final baseCost = 35.0;
            final baseHeat = 0.12;
            final costFatigueMult = 1.0 + (driverFatigueAvg / 100.0) * 0.05; // up to +5% when very fatigued
            int cost = (baseCost * hopFactor * (1.0 - 0.12 * vehicle) * costFatigueMult).round().clamp(5, 300);
            // Base heat scaled by police presence
            final heatIncBase = baseHeat * hopFactor;
            final police = district.policePresence;
            double heatInc = (heatIncBase * (0.9 + 0.5 * police)).clamp(0.0, 0.35);
            // vehicle helps a bit
            heatInc *= (1.0 - 0.06 * vehicle).clamp(0.6, 1.0);
            // driver helps more with heat; fatigue reduces effect
            final driverMod = (1.0 - 0.07 * driverSkill + (driverFatigueAvg / 100.0) * 0.05).clamp(0.5, 1.1);
            heatInc *= driverMod;
            final bonus = city.bonuses[district.id] ?? const {};
            final heatDecayBonus = (bonus['heatDecayBonus'] ?? 0).toDouble();
            final storageBonus = (bonus['storageBonus'] ?? 0).toInt();
    ref.read(gameStateProvider.notifier).travel(
                  cost,
                  heatInc,
                  toDistrictIndex: index,
      toDistrictId: district.id,
                  heatDecayBonus: heatDecayBonus,
                  storageBonus: storageBonus,
                );
            Navigator.of(context).pop();
          },
          child: const Text('Travel here'),
        ),
        TextButton(
          onPressed: controllingFaction == null
              ? null
              : () {
                  ref.read(factionProvider.notifier).truce(controllingFaction.id);
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Requested truce with ${controllingFaction.name}.')));
                },
          child: const Text('Request Truce'),
        ),
        TextButton(
          onPressed: controllingFaction == null
              ? null
              : () {
                  // tribute: pay fee, bump rep via controller, ease heat
                  final tribute = 100;
                  if (gs['cash'] >= tribute) {
                    ref.read(gameStateProvider.notifier).spendCash(tribute);
                    ref.read(factionProvider.notifier).tribute(controllingFaction.id, tribute);
                    // slight heat relief
                    ref.read(gameStateProvider.notifier).travel(0, -0.05);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Paid tribute to ${controllingFaction.name}.')));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not enough cash for tribute.')));
                  }
                },
          child: const Text('Pay Tribute'),
        ),
        TextButton(
          onPressed: () {
            final metaRaw = ref.read(gameStateProvider.select((s) => s['meta']));
            final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
            final prot = meta['protectionByDistrict'] is Map
                ? Map<String, int>.from((meta['protectionByDistrict'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt())))
                : <String, int>{};
            prot[district.id] = (prot[district.id] ?? 0) + 2; // add 2 days protection
            ref.read(gameStateProvider.notifier).setProtectionByDistrict(prot);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Secured protection for 2 days.')));
          },
          child: const Text('Buy Protection (+2d)'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
