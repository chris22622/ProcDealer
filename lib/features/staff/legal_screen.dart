import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/game_state.dart';

class LegalScreen extends ConsumerWidget {
  const LegalScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaRaw = ref.watch(gameStateProvider.select((s) => s['meta']));
    final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
    final cases = (meta['legalCases'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? const <Map<String, dynamic>>[];
    final retainer = (meta['lawyerRetainer'] ?? 0) as int;
    final quality = (meta['lawyerQuality'] ?? 0) as int;
    return Scaffold(
      appBar: AppBar(title: const Text('Legal')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Lawyer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Retainer: \$${retainer} · Quality: ${quality}'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: () => ref.read(gameStateProvider.notifier).setLawyer(retainer: retainer + 100),
                        child: const Text('Increase Retainer +\$100'),
                      ),
                      OutlinedButton(
                        onPressed: () => ref.read(gameStateProvider.notifier).setLawyer(retainer: retainer, quality: (quality + 1).clamp(0, 3)),
                        child: const Text('Improve Quality'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Open Cases', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...cases.map((c) => Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${c['type']=='crew' ? 'Crew' : 'Player'} case · Severity ${c['severity'] ?? 1}',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('Status: ${c['status']} · Hearing in ${c['daysUntilHearing']}d · Bail: \$${c['bail'] ?? 0}'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (((c['bail'] ?? 0) as int) > 0 && (c['status'] ?? 'open') == 'open')
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: ElevatedButton(
                            onPressed: () => ref.read(gameStateProvider.notifier).payBailForCase(c['id'] as String),
                            child: const Text('Pay Bail'),
                          ),
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
