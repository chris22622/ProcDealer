import 'package:flutter/material.dart';
import '../../core/types.dart';
import '../../core/audio_service.dart';
import '../shared/risk_meter.dart';
import '../shared/snackbar_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/game_state.dart';
import '../../core/law.dart';
import '../../state/crew_provider.dart';
import '../../state/economy_provider.dart';
import '../../state/city_provider.dart';
import '../../core/balance.dart';
import '../../state/event_provider.dart';
import '../../state/faction_provider.dart';

class DealModal extends StatefulWidget {
  final Offer offer;
  const DealModal({Key? key, required this.offer}) : super(key: key);

  @override
  State<DealModal> createState() => _DealModalState();
}

class _DealModalState extends State<DealModal> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _adjust = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    setState(() {
      _adjust = (_controller.value - 0.5) * 0.2; // ±10%
    });
    // Respect Settings: sound + haptics via AudioService
    if (widget.offer.risk > 0.7) {
      AudioService.alert();
    } else if (widget.offer.risk > 0.2) {
      AudioService.confirm();
    } else {
      AudioService.click();
    }
    // Compute bust chance based on heat and modifiers
    final ref = ProviderScope.containerOf(context, listen: false).read;
  final gs = ref(gameStateProvider);
    final crew = ref(crewProvider);
  // Read upgrades early (scanner used in police mod below)
  final upgradesRaw = gs['upgrades'];
  final upgrades = upgradesRaw is Map ? Map<String, dynamic>.from(upgradesRaw) : <String, dynamic>{};
  final scannerLevel = (upgrades['scanner'] ?? 0) as int;
  final safehouseLevel = (upgrades['safehouse'] ?? 0) as int;
  double chance = Law.bustChance((gs['heat'] as num).toDouble());
  // Apply economy/day risk modifier (weather, festivals)
  final eco = ref(economyProvider);
  chance *= eco.riskMod();
  // Apply local police presence modifier
  final city = ref(cityProvider);
  final metaRaw = gs['meta'];
  final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
  final dIdx = (meta['currentDistrict'] ?? 0) as int;
  final police = (dIdx >= 0 && dIdx < city.districts.length) ? city.districts[dIdx].policePresence : 0.5;
  final dId = (dIdx >= 0 && dIdx < city.districts.length) ? city.districts[dIdx].id : '';
  final corruption = city.bonuses[dId]?['corruption'] is num ? (city.bonuses[dId]!['corruption'] as num).toDouble() : 0.5;
  double policeMod = Law.policeRiskMod((gs['heat'] as num).toDouble(), police);
  // Evidence and pattern add risk pressure
  final evidence = ((meta['evidence'] ?? 0.0) as num).toDouble();
  final dKey = 'd${dIdx}_${widget.offer.drugId}';
  final patRaw = meta['patternByDistrictDrug'];
  final pattern = patRaw is Map ? Map<String, dynamic>.from(patRaw) : <String, dynamic>{};
  final patternCount = (pattern[dKey] ?? 0) as int;
  // Patrol sweep in this district today increases risk
  final todaysEvents = ref(eventProvider);
  if (dIdx >= 0 && dIdx < city.districts.length) {
    final dId = city.districts[dIdx].id;
    final hasSweep = todaysEvents.any((e) => e.type == 'Patrol Sweep' && e.districtId == dId);
    if (hasSweep) policeMod *= 1.2;
  final hasProbe = todaysEvents.any((e) => e.type == 'Corruption Probe' && e.districtId == dId);
  if (hasProbe) policeMod *= 1.15;
  final hasTip = todaysEvents.any((e) => e.type == 'Informant Tip' && e.districtId == dId);
  if (hasTip) policeMod *= 1.1;
  }
  if ((meta['policeBribedToday'] ?? false) == true) {
    policeMod *= Balance.policeBribeFactor;
  }
  // Scanner has an extra effect specifically on police pressure (in addition to earlier effect)
  policeMod *= (1 - 0.04 * scannerLevel).clamp(0.75, 1.0);
  // Evidence grows bust chance sublinearly; pattern adds multiplicatively
  final evidenceMod = (1 + (evidence).clamp(0.0, 10.0) * 0.03);
  final patternMod = (1 + (patternCount * 0.06)).clamp(1.0, 1.6);
  // Lower corruption => stricter enforcement
  final corruptionMod = (1.1 - corruption * 0.2).clamp(0.9, 1.1);
  chance *= policeMod * evidenceMod * patternMod * corruptionMod;
    // Scanner and Safehouse reduce effective chance
    chance *= (1 - 0.1 * scannerLevel).clamp(0.7, 1.0);
    chance *= (1 - 0.05 * safehouseLevel).clamp(0.75, 1.0);
    // Fixer reduces chance further
    final hasFixer = crew.crew.any((c) => c.role == 'Fixer');
    if (hasFixer) chance *= 0.85;

    // Risk from offer scales it
    chance *= (1 + widget.offer.risk);

    final rng = gs['day'] as int; // lightweight seed
    final roll = (DateTime.now().microsecondsSinceEpoch ^ rng) % 1000 / 1000.0;
    // Undercover sting check: if an 'Undercover Sting' is present in district, run a quick scanner mini-check; fail => auto-bust
    bool stingBust = false;
    try {
      final todaysEvents = ref(eventProvider);
      final metaRaw2 = gs['meta'];
      final meta2 = metaRaw2 is Map ? Map<String, dynamic>.from(metaRaw2) : <String, dynamic>{};
      final dIdx2 = (meta2['currentDistrict'] ?? 0) as int;
      final dId2 = (dIdx2 >= 0 && dIdx2 < city.districts.length) ? city.districts[dIdx2].id : '';
      final hasSting = todaysEvents.any((e) => e.type == 'Undercover Sting' && e.districtId == dId2);
      if (hasSting) {
        // Scanner mini-check: succeed if scannerLevel + Fixer skill edge beats a threshold roll
        final fixerSkill = crew.crew.where((c) => c.role == 'Fixer').fold<int>(0, (a, b) => a + b.skill);
        final fixerFatigue = crew.crew.where((c) => c.role == 'Fixer').fold<int>(0, (a, b) => a + b.fatigue);
        final fixerMod = (fixerSkill * 2 - (fixerFatigue ~/ 20)).clamp(0, 10);
        final mini = (scannerLevel * 2 + fixerMod) / 20.0; // 0..1
        final tr = ((DateTime.now().millisecondsSinceEpoch >> 4) & 1023) / 1023.0;
        stingBust = tr > mini; // fail check => bust
      }
    } catch (_) {}
  final isBust = stingBust || (roll < chance.clamp(0.0, 0.9));
    Navigator.of(context).pop();
    if (isBust) {
      await showDialog(
        context: context,
        builder: (_) => _BustDialog(chance: chance),
      );
    } else {
      // Complete the sale at negotiated price per unit
      final ref = ProviderScope.containerOf(context, listen: false).read;
  final gs = ref(gameStateProvider);
  final invRaw = gs['inventory'];
  final inv = Inventory.fromJson(invRaw is Map ? Map<String, dynamic>.from(invRaw) : <String, dynamic>{});
      final have = inv.drugs[widget.offer.drugId] ?? 0;
      final qty = have >= widget.offer.qty ? widget.offer.qty : have;
  if (qty > 0) {
        final unit = widget.offer.priceOffer;
        int negotiatedUnit = (unit * (1 + _adjust)).round();
        // VIP price bonus if a contract exists for this drug and term is active, only for VIP offers
        try {
          if (widget.offer.customerType == 'VIP') {
            final day = gs['day'] as int;
            final metaRaw = gs['meta'];
            final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
            final vipList = (meta['vipContracts'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? const <Map<String, dynamic>>[];
            final match = vipList.firstWhere(
              (v) => (v['drugId'] ?? '') == widget.offer.drugId && (v['contractedUntilDay'] ?? 0) >= day,
              orElse: () => const {},
            );
            if (match.isNotEmpty) {
              final bonus = ((match['priceBonus'] ?? 1.0) as num).toDouble();
              negotiatedUnit = (negotiatedUnit * bonus).round();
            }
          }
        } catch (_) {}
        final total = negotiatedUnit * qty;
        // Faction tax if district controlled: small cut of sale, except in your home district
        int tax = 0;
        try {
          final metaRaw2 = gs['meta'];
          final meta2 = metaRaw2 is Map ? Map<String, dynamic>.from(metaRaw2) : <String, dynamic>{};
          final homeId = (meta2['homeDistrictId'] ?? '') as String;
          final curId = (dIdx >= 0 && dIdx < city.districts.length) ? city.districts[dIdx].id : '';
          final isHome = homeId.isNotEmpty && curId == homeId;
          final factions = ref(factionProvider);
          final controlling = factions.firstWhere((f) => f.id == (city.districts[dIdx].factionId ?? ''), orElse: () => Faction(id: '', name: '', reputation: 0));
          if (!isHome && controlling.id.isNotEmpty) {
            final rep = controlling.reputation; // better rep reduces tax rate
            final rate = (0.05 - (rep / 2000.0)).clamp(0.02, 0.07);
            tax = (total * rate).round();
          }
        } catch (_) {}
        ref(gameStateProvider.notifier).sell(widget.offer.drugId, qty, total - tax, customerType: widget.offer.customerType);
        if (tax > 0) {
          ref(gameStateProvider.notifier).addFactionTaxToday(tax);
        }
        if (tax > 0) {
          SnackbarService.show(context, 'Paid tribute -\$${tax}', color: Colors.redAccent);
        } else {
          // If in home district, optionally surface a friendly note once
          try {
            final metaRaw2 = gs['meta'];
            final meta2 = metaRaw2 is Map ? Map<String, dynamic>.from(metaRaw2) : <String, dynamic>{};
            final homeId = (meta2['homeDistrictId'] ?? '') as String;
            final curId = (dIdx >= 0 && dIdx < city.districts.length) ? city.districts[dIdx].id : '';
            if (homeId.isNotEmpty && homeId == curId) {
              SnackbarService.show(context, 'No tribute in your home turf.', color: Colors.green);
            }
          } catch (_) {}
        }
        SnackbarService.show(
          context,
          'Sold $qty x ${widget.offer.drugId} for \$${total}',
          color: Colors.teal,
        );
      } else {
        SnackbarService.show(context, 'No inventory to sell.', color: Colors.orangeAccent);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Negotiate Deal'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${widget.offer.qty}x ${widget.offer.drugId} for \u0024${widget.offer.priceOffer}'),
          const SizedBox(height: 8),
          RiskMeter(risk: widget.offer.risk),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _showBustBreakdown,
              icon: const Icon(Icons.info_outline, size: 16),
              label: const Text('Why?'),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _onTap,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(80, 80),
                  painter: _RingPainter(_controller.value),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text('Tap inside the ring to negotiate!'),
        ],
      ),
    );
  }

  void _showBustBreakdown() {
    final read = ProviderScope.containerOf(context, listen: false).read;
    final gs = read(gameStateProvider);
    final crew = read(crewProvider);
    final eco = read(economyProvider);
    final city = read(cityProvider);
    final metaRaw = gs['meta'];
    final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
    final heat = (gs['heat'] as num).toDouble();
    final dIdx = (meta['currentDistrict'] ?? 0) as int;
    final police = (dIdx >= 0 && dIdx < city.districts.length) ? city.districts[dIdx].policePresence : 0.5;
    final base = Law.bustChance(heat);
  final econ = eco.riskMod();
    // upgrades
    final upgradesRaw = gs['upgrades'];
    final upgrades = upgradesRaw is Map ? Map<String, dynamic>.from(upgradesRaw) : <String, dynamic>{};
    final scannerLevel = (upgrades['scanner'] ?? 0) as int;
    final safehouseLevel = (upgrades['safehouse'] ?? 0) as int;
    // police mod
    double policeMod = Law.policeRiskMod(heat, police);
    final todaysEvents = read(eventProvider);
    if (dIdx >= 0 && dIdx < city.districts.length) {
      final dId = city.districts[dIdx].id;
      final hasSweep = todaysEvents.any((e) => e.type == 'Patrol Sweep' && e.districtId == dId);
      if (hasSweep) policeMod *= 1.2;
    }
    if ((meta['policeBribedToday'] ?? false) == true) {
      policeMod *= Balance.policeBribeFactor;
    }
    final policeScanner = (1 - 0.04 * scannerLevel).clamp(0.75, 1.0);
    policeMod *= policeScanner;
    final scanner = (1 - 0.1 * scannerLevel).clamp(0.7, 1.0);
    final safehouse = (1 - 0.05 * safehouseLevel).clamp(0.75, 1.0);
  final fixer = crew.crew.any((c) => c.role == 'Fixer') ? 0.85 : 1.0;
  // district corruption
  final dId = (dIdx >= 0 && dIdx < city.districts.length) ? city.districts[dIdx].id : '';
  final corruption = city.bonuses[dId]?['corruption'] is num ? (city.bonuses[dId]!['corruption'] as num).toDouble() : 0.5;
    final offerRisk = (1 + widget.offer.risk);
  final evidence = ((meta['evidence'] ?? 0.0) as num).toDouble();
  final dKey = 'd${dIdx}_${widget.offer.drugId}';
  final patRaw = meta['patternByDistrictDrug'];
  final pattern = patRaw is Map ? Map<String, dynamic>.from(patRaw) : <String, dynamic>{};
  final patternCount = (pattern[dKey] ?? 0) as int;
  final evidenceMod = (1 + (evidence).clamp(0.0, 10.0) * 0.03);
  final patternMod = (1 + (patternCount * 0.06)).clamp(1.0, 1.6);
  final corruptionMod = (1.1 - corruption * 0.2).clamp(0.9, 1.1);
  final finalChance = (base * econ * policeMod * evidenceMod * patternMod * corruptionMod * scanner * safehouse * fixer * offerRisk).clamp(0.0, 0.9);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Bust chance breakdown'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _line('Base (heat)', base),
            _line('Economy/Day', econ),
            _line('Police pressure', policeMod),
            _line('Evidence', evidenceMod),
            _line('Pattern (same district)', patternMod),
            _line('Corruption', corruptionMod),
            _line('Scanner vs police', policeScanner.toDouble()),
            _line('Scanner (general)', scanner.toDouble()),
            _line('Safehouse', safehouse.toDouble()),
            _line('Fixer', fixer.toDouble()),
            _line('Offer risk', offerRisk.toDouble()),
            const Divider(),
            Text('Final: ${(finalChance * 100).toStringAsFixed(0)}%'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _line(String label, double mod) {
    final pct = ((mod - 1) * 100);
    final sign = pct >= 0 ? '+' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text('x${mod.toStringAsFixed(2)}  ($sign${pct.toStringAsFixed(0)}%)'),
        ],
      ),
    );
  }
}

class _BustDialog extends ConsumerWidget {
  final double chance;
  const _BustDialog({Key? key, required this.chance}) : super(key: key);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cash = ref.watch(gameStateProvider)['cash'] as int;
    final bail = (cash * 0.25).clamp(100, 1000).toInt();
    return AlertDialog(
      title: const Text('Bust!'),
      content: Text('You got busted (p=${(chance * 100).toStringAsFixed(0)}%). Pay bail or take a plea?'),
      actions: [
        TextButton(
          onPressed: () {
    ref.read(gameStateProvider.notifier).takePleaDeal();
            Navigator.of(context).pop();
          },
          child: const Text('Plea'),
        ),
        ElevatedButton(
          onPressed: cash >= bail
              ? () {
      ref.read(gameStateProvider.notifier).payBail(bail);
                  Navigator.of(context).pop();
                }
              : null,
          child: Text('Pay Bail (\$$bail)'),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.tealAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawArc(rect, 0, 2 * 3.1415 * (1 - progress), false, paint);
  }
  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}
