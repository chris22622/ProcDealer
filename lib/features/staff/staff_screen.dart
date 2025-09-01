import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/game_state.dart';
import 'suppliers_screen.dart';
import 'diplomacy_screen.dart';
import 'crew_screen.dart';
import 'vip_contracts_screen.dart';
import 'legal_screen.dart';
import 'ai_intel_screen.dart';

class StaffScreen extends ConsumerWidget {
  const StaffScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaRaw = ref.watch(gameStateProvider.select((s) => s['meta']));
    final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
    final cases = (meta['legalCases'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? const <Map<String, dynamic>>[];
    final openCount = cases.where((c) => (c['status'] ?? 'open') != 'resolved').length;
  final pressRaw = meta['policePressureByDid'];
  final hasPressure = pressRaw is Map && pressRaw.isNotEmpty;
    return Center(
      child: Card(
        margin: const EdgeInsets.all(32),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people, size: 64),
              const SizedBox(height: 16),
              const Text('Crew & Relations', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SuppliersScreen())),
                icon: const Icon(Icons.factory),
                label: const Text('Suppliers'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VipContractsScreen())),
                icon: const Icon(Icons.star),
                label: const Text('VIP Contracts'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CrewScreen())),
                icon: const Icon(Icons.badge),
                label: const Text('Crew'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiplomacyScreen())),
                icon: const Icon(Icons.groups_2),
                label: const Text('Factions'),
              ),
              const SizedBox(height: 12),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalScreen())),
                    icon: const Icon(Icons.gavel),
                    label: const Text('Legal'),
                  ),
                  if (openCount > 0)
                    Positioned(
                      right: -8,
                      top: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(12)),
                        child: Text('$openCount', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiIntelScreen())),
                    icon: const Icon(Icons.smart_toy),
                    label: const Text('AI Intel'),
                  ),
                  if (hasPressure)
                    Positioned(
                      right: -8,
                      top: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.orangeAccent, borderRadius: BorderRadius.circular(12)),
                        child: const Text('!', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
