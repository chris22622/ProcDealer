import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/economy_provider.dart';
import '../../state/event_provider.dart';
import '../../state/game_state.dart';
import '../../state/supplier_provider.dart';
import '../../state/city_provider.dart';
import '../../state/faction_provider.dart';

class RecapScreen extends ConsumerWidget {
  const RecapScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eco = ref.watch(economyProvider);
    final events = ref.watch(eventProvider);
    final gs = ref.watch(gameStateProvider);
    final suppliers = ref.watch(supplierProvider);
    final factions = ref.watch(factionProvider);
    final avgRep = factions.isEmpty ? 0 : (factions.map((f) => f.reputation).reduce((a, b) => a + b) / factions.length).round();
    final metaRaw = gs['meta'];
    final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
    final lastInterest = (meta['lastInterest'] ?? 0) as int;
    final lastMaint = (meta['lastMaintenanceFee'] ?? 0) as int;
    final lastSla = (meta['lastSlaPenalty'] ?? 0) as int;
    final lastVip = (meta['lastVipPenalty'] ?? 0) as int;
    final lastUnits = (meta['lastUnitsSold'] ?? 0) as int;
    final lastCashDelta = (meta['lastCashDelta'] ?? 0) as int;
    final lastAudit = (meta['lastAuditFee'] ?? 0) as int;
    final lastFactionTax = (meta['lastFactionTax'] ?? 0) as int;
    final lastLoanInt = (meta['lastLoanInterest'] ?? 0) as int;
    final lastLoanAutoPaid = (meta['lastLoanAutoPaid'] ?? 0) as int;
    final lastCrewConflict = (meta['lastCrewConflict'] ?? 0) as int;
    final lastCrewBankCredit = (meta['lastCrewBankCredit'] ?? 0) as int;
    final lastShellDrift = (meta['lastShellDrift'] ?? 0) as int;
    final lastCryptoPnl = (meta['lastCryptoPnl'] ?? 0) as int;
    final lastInsurancePremium = (meta['lastInsurancePremium'] ?? 0) as int;
  final lastLegalFines = (meta['lastLegalFines'] ?? 0) as int;
    final evidence = ((meta['evidence'] ?? 0.0) as num).toDouble();
    final bankDelta = (meta['bankDeltaToday'] ?? 0) as int;
    final rewarded = (meta['objectiveRewarded'] ?? false) as bool;
    // Aggregate crew sales by district for a quick breakdown
    final soldByDDRaw = meta['soldByDistrictDrugUnits'];
    final Map<String, int> unitsByDid = {};
    if (soldByDDRaw is Map) {
      soldByDDRaw.forEach((k, v) {
        final key = k.toString();
        if (key.startsWith('did_')) {
          final rest = key.substring(4);
          final idx = rest.indexOf('_');
          if (idx > 0) {
            final did = rest.substring(0, idx);
            unitsByDid[did] = (unitsByDid[did] ?? 0) + (v as num).toInt();
          }
        }
      });
    }
    // Per-member earnings from last day if available
    final lastCrewEarnRaw = meta['lastCrewEarnings'];
    final List<Map<String, dynamic>> lastCrewEarnings = lastCrewEarnRaw is List
        ? lastCrewEarnRaw.map((e) => Map<String, dynamic>.from(e)).toList()
        : const <Map<String, dynamic>>[];
    final city = ref.watch(cityProvider);
    String didName(String did) {
      try {
        return city.districts.firstWhere((d) => d.id == did).name;
      } catch (_) {
        return did;
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Day Recap')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text('Day ${gs['day'] - 1} ➜ ${gs['day']}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Heat radar:'),
                const SizedBox(width: 8),
                _HeatRadar(level: (gs['heat'] as num).toDouble()),
              ],
            ),
            const SizedBox(height: 12),
            Text('Economy: ${eco.weather} · Payday ${eco.payday ? 'Yes' : 'No'} · Festival ${eco.festival ? 'Yes' : 'No'}'),
            const SizedBox(height: 8),
            Text('Wages paid: \$${(gs['meta']['lastWagesPaid'] ?? 0)}'),
            if (lastInterest > 0) Text('Bank interest compounded: \$${lastInterest}'),
            if (lastMaint > 0) Text('Bank maintenance fee: -\$${lastMaint}'),
            if (lastSla > 0) Text('SLA penalties: -\$${lastSla}'),
            if (lastVip > 0) Text('VIP penalties: -\$${lastVip}'),
            if (lastAudit > 0) Text('Audit fee: -\$${lastAudit}'),
            if (lastFactionTax > 0) Text('Faction tribute: -\$${lastFactionTax}'),
            if (lastLoanInt > 0) Text('Loan interest accrued: -\$${lastLoanInt}'),
            if (lastLoanAutoPaid > 0) Text('Loan auto payment: -\$${lastLoanAutoPaid}'),
            if (lastCrewBankCredit > 0) Text('Crew banked today: +\$${lastCrewBankCredit}'),
            if (lastCrewConflict > 0) Text('Crew conflicts cost: -\$${lastCrewConflict}'),
            if (lastShellDrift != 0) Text('Shell fund drift: ${lastShellDrift >= 0 ? '+' : ''}\$${lastShellDrift}'),
            if (lastCryptoPnl != 0) Text('Crypto P/L: ${lastCryptoPnl >= 0 ? '+' : ''}\$${lastCryptoPnl}'),
            if (lastInsurancePremium > 0) Text('Insurance premium: -\$${lastInsurancePremium}'),
            if (lastLegalFines > 0) Text('Legal fines: -\$${lastLegalFines}'),
            if (unitsByDid.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Crew sales by district', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              ...(() {
                final list = unitsByDid.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                return list.take(5).map((e) => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(didName(e.key))),
                        Text('${e.value} units'),
                      ],
                    ));
              }())
            ],
            if (lastCrewEarnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Crew earnings by member', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              ...lastCrewEarnings.map((e) => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('${e['role'] ?? e['id']}')),
                      Text('+\$${e['earned'] ?? 0}'),
                    ],
                  )),
            ],
            Text('Units sold: $lastUnits'),
            Text('Cash delta: ${lastCashDelta >= 0 ? '+' : ''}\$${lastCashDelta}'),
            Text('Evidence now: ${evidence.toStringAsFixed(2)}'),
            if (bankDelta != 0) Text('Bank moved today: ${bankDelta >= 0 ? '+' : ''}\$${bankDelta}'),
            if (rewarded) const Text('Objective reward granted', style: TextStyle(color: Colors.amber)),
            const SizedBox(height: 12),
            Text('Modifiers:'),
            Text('• Brand rep: ${gs['meta']['brandRep']}'),
            Text('• Purity boost: +${gs['meta']['purityBoost']}'),
            Text('• Supplier contracts: ${suppliers.where((s) => s.contracted).length}'),
            Text('• Faction avg rep: $avgRep'),
            Text('• Drought today: ${events.any((e) => e.type == 'Drought') ? 'Yes' : 'No'}'),
            const SizedBox(height: 12),
            Text('Events:'),
            ...events.map((e) => Text('• ${e.desc}')),
            const SizedBox(height: 24),
          ],
        ),
      )),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue'),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeatRadar extends StatelessWidget {
  final double level; // 0..1
  const _HeatRadar({Key? key, required this.level}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(40, 40),
      painter: _HeatRadarPainter(level),
    );
  }
}

class _HeatRadarPainter extends CustomPainter {
  final double level;
  _HeatRadarPainter(this.level);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final bg = Paint()..color = Colors.white.withOpacity(0.08);
    final fg = Paint()..color = Color.lerp(Colors.greenAccent, Colors.redAccent, level.clamp(0, 1))!;
    canvas.drawCircle(center, radius, bg);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -3.1415/2, 2*3.1415*level.clamp(0,1), true, fg..style = PaintingStyle.fill..color = fg.color.withOpacity(0.35));
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = fg.color;
    canvas.drawCircle(center, radius, ring);
  }
  @override
  bool shouldRepaint(covariant _HeatRadarPainter old) => old.level != level;
}
