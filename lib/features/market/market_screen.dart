import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/market_provider.dart';
import '../../state/customer_provider.dart';
// types are used via providers' models; no direct import needed here
import 'deal_modal.dart';
import 'customer_avatar.dart';
import '../shared/animated_confetti.dart';
import '../../state/game_state.dart';
import '../shared/snackbar_service.dart';
import '../../core/types.dart';
import '../../state/city_provider.dart';
import '../../core/balance.dart';
import '../../data/drug_catalog.dart';
import '../../state/faction_provider.dart';

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({Key? key}) : super(key: key);
  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  bool _showConfetti = false;
  void _showProjectedDeductionsDialog(BuildContext context) {
    final gs = ref.read(gameStateProvider);
    final wagesDue = (gs['meta']['wagesDue'] ?? 0) as int;
    final loansRaw = (gs['meta']['loans'] as List<dynamic>?) ?? const [];
    final loans = loansRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    // Include faction tribute projected (based on today's recorded tribute so far)
    final factionTaxToday = (gs['meta']['factionTaxToday'] ?? 0) as int;
    int totalMin = 0;
    final lines = <Widget>[];
    for (final l in loans) {
      final id = (l['id'] ?? '') as String;
      final bal = ((l['balance'] ?? 0) as num).toDouble();
      if (bal <= 0) continue;
      final minByRate = (bal * Balance.loanMinPaymentRate).round();
      final minPay = minByRate < Balance.loanMinPaymentBase ? Balance.loanMinPaymentBase : minByRate;
      final projInt = (bal * (((l['dailyRate'] ?? 0.0) as num).toDouble())).round();
      totalMin += minPay;
      final shortId = id.isNotEmpty && id.length > 4 ? id.substring(id.length - 4) : id;
      lines.add(Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Loan ${shortId}'),
          Text('Min -\$${minPay} · Int -\$${projInt}')
        ],
      ));
    }
    final total = wagesDue + totalMin + factionTaxToday;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Projected deductions'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Crew wages'),
                  Text('-\$${wagesDue}')
                ],
              ),
              const SizedBox(height: 8),
              if (lines.isNotEmpty) const Text('Loans:'),
              ...lines,
              if (factionTaxToday > 0) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tribute paid today'),
                    Text('-\$${factionTaxToday}')
                  ],
                ),
              ],
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total'),
                  Text('-\$${total}')
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
  final prices = ref.watch(marketProvider);
  final offers = ref.watch(customerProvider);
  final invRaw = ref.watch(gameStateProvider)['inventory'];
  final inv = invRaw is Map ? Map<String, dynamic>.from(invRaw) : <String, dynamic>{};
  final holdings = Inventory.fromJson(inv).drugs;
    final gs = ref.watch(gameStateProvider);
  final bank = (gs['meta']['bank'] ?? 0) as int;
  final wagesDue = (gs['meta']['wagesDue'] ?? 0) as int;
  final factionTaxToday = (gs['meta']['factionTaxToday'] ?? 0) as int;
  final loansRaw = (gs['meta']['loans'] as List<dynamic>?) ?? const [];
  final loans = loansRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  int minDue = 0;
  for (final l in loans) {
    final bal = ((l['balance'] ?? 0) as num).toDouble();
    if (bal <= 0) continue;
    final minByRate = (bal * Balance.loanMinPaymentRate).round();
    final minPay = minByRate < Balance.loanMinPaymentBase ? Balance.loanMinPaymentBase : minByRate;
    minDue += minPay;
  }
  final city = ref.watch(cityProvider);
  final dIdx = (gs['meta']['currentDistrict'] ?? 0) as int;
  final police = (dIdx >= 0 && dIdx < city.districts.length) ? city.districts[dIdx].policePresence : 0.5;
  final curDid = (dIdx >= 0 && dIdx < city.districts.length) ? city.districts[dIdx].id : '';
  final homeDid = ((gs['meta']['homeDistrictId'] ?? '') as String);
  final isHome = homeDid.isNotEmpty && curDid == homeDid;
  final inflRaw = (gs['meta']['influenceByDistrict'] ?? const <String, int>{});
  final influence = inflRaw is Map ? (inflRaw[curDid] ?? 0) as int : 0;
  // Tribute rate chip for clarity
  double tributeRate = 0.0;
  try {
    final factionId = (dIdx >= 0 && dIdx < city.districts.length) ? (city.districts[dIdx].factionId ?? '') : '';
    if (!isHome && factionId.isNotEmpty) {
      final factions = ref.watch(factionProvider);
      final controlling = factions.where((f) => f.id == factionId).isEmpty
          ? null
          : factions.firstWhere((f) => f.id == factionId);
      if (controlling != null) {
        final rep = controlling.reputation;
        tributeRate = (0.05 - (rep / 2000.0)).clamp(0.02, 0.07);
      } else {
        tributeRate = 0.05; // default estimate
      }
    }
  } catch (_) {}
  final heat = (gs['heat'] as num).toDouble();
  final bribed = (gs['meta']['policeBribedToday'] ?? false) == true;
  final vipList = (gs['meta']['vipContracts'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? const <Map<String, dynamic>>[];
  final dayPart = (gs['meta']['dayPart'] ?? 'Day') as String;
  final districtId = (dIdx >= 0 && dIdx < city.districts.length) ? city.districts[dIdx].id : '';
    final cash = gs['cash'] as int;
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Colors.white10,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Funds: Cash \$${cash} · Bank \$${bank}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department, size: 16, color: Colors.orangeAccent),
                        const SizedBox(width: 4),
                        Text('Heat ${(heat * 100).toStringAsFixed(0)}%'),
                        const SizedBox(width: 12),
                        const Icon(Icons.local_police, size: 16, color: Colors.lightBlueAccent),
                        const SizedBox(width: 4),
                        Text('Police ${(police * 100).toStringAsFixed(0)}%'),
                        if (bribed) ...[
                          const SizedBox(width: 12),
                          Chip(
                            label: const Text('Bribed today'),
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(Icons.verified, color: Colors.green, size: 16),
                          ),
                        ],
                        const Spacer(),
                        if (curDid.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Chip(
                              label: Text('Influence ${influence}%'),
                              visualDensity: VisualDensity.compact,
                              avatar: const Icon(Icons.track_changes, size: 16, color: Colors.cyanAccent),
                            ),
                          ),
                        if (isHome)
                          Chip(
                            label: const Text('Home turf: no tribute'),
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(Icons.home, size: 16, color: Colors.lightGreenAccent),
                          ),
                        if (!isHome && tributeRate > 0) ...[
                          const SizedBox(width: 8),
                          Chip(
                            label: Text('Tribute ~${(tributeRate * 100).toStringAsFixed(1)}%'),
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(Icons.monetization_on, size: 16, color: Colors.redAccent),
                          ),
                        ],
                        const SizedBox(width: 8),
                        if (wagesDue > 0 || minDue > 0)
                          ActionChip(
                            label: Text('Projected deductions: -\$${wagesDue + minDue + factionTaxToday}'),
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(Icons.schedule, size: 16, color: Colors.amberAccent),
                            onPressed: () => _showProjectedDeductionsDialog(context),
                          ),
                        ElevatedButton.icon(
                          onPressed: bribed
                              ? null
                              : cash >=  Balance.policeBribeCost
                              ? () {
                                  ref.read(gameStateProvider.notifier).bribePolice();
                                  SnackbarService.show(context, 'Bribed patrols. Lowered police pressure today.');
                                }
                              : null,
                          icon: const Icon(Icons.payments),
                          label: Text(bribed ? 'Bribed' : 'Bribe \$${Balance.policeBribeCost}'),
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (vipList.isNotEmpty) ...[
                      const Text('VIP Contracts', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: vipList.map((v) {
                          final drugId = v['drugId'] as String?;
                          final d = drugCatalog.firstWhere((x) => x.id == drugId, orElse: () => drugCatalog.first);
                          final until = v['contractedUntilDay'] ?? 0;
                          final minDaily = v['minDaily'] ?? 0;
                          return Chip(label: Text('${d.name}: $minDaily/day until D$until'));
                        }).toList(),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final e in holdings.entries.where((e) => e.value > 0))
                          Chip(label: Text('${e.key}: ${e.value}')),
                        if (holdings.entries.every((e) => e.value == 0)) const Text('No inventory yet. Tap a price below to buy.'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: cash >= 100 ? () => ref.read(gameStateProvider.notifier).depositBank(100) : null,
                          icon: const Icon(Icons.savings),
                          label: const Text('Deposit 100'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: bank >= 100 ? () => ref.read(gameStateProvider.notifier).withdrawBank(100) : null,
                          icon: const Icon(Icons.account_balance_wallet),
                          label: const Text('Withdraw 100'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
            Text('Market Prices', style: Theme.of(context).textTheme.titleLarge),
            ...prices.map((e) => Card(
                  child: ListTile(
                    title: Text(e['drug'].name),
                    subtitle: const Text('Tap to choose quantity'),
                    trailing: Text('\u0024${e['price']}'),
                    onTap: () => _showBuyDialog(context, e['drug'].id as String, e['drug'].name as String, e['price'] as int),
                  ),
                )),
            const SizedBox(height: 24),
            Text('Today\'s Offers', style: Theme.of(context).textTheme.titleLarge),
            ...offers.map((offer) => Card(
                  child: ListTile(
                    leading: CustomerAvatar(type: offer.customerType),
                    title: Text('${offer.customerType} wants ${offer.qty}x ${offer.drugId}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Offer: \u0024${offer.priceOffer} | Risk: ${(offer.risk * 100).toStringAsFixed(0)}%'),
                        Text(_flavorText(offer.customerType), style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                        if (offer.customerType == 'VIP') ...[
                          Wrap(
                            spacing: 6,
                            children: () {
                              final chips = <Widget>[];
                              try {
                                final match = vipList.firstWhere(
                                  (v) => (v['drugId'] ?? '') == offer.drugId && (v['contractedUntilDay'] ?? 0) >= gs['day'],
                                  orElse: () => const {},
                                );
                                if (match.isNotEmpty) {
                                  final restrict = (match['restrictDistrictId'] ?? '') as String?;
                                  final window = (match['window'] ?? '') as String?;
                                  if (restrict != null && restrict.isNotEmpty) {
                                    final ok = districtId == restrict;
                                    chips.add(Chip(label: Text('Route ${ok ? 'OK' : 'Wrong district'}')));
                                  }
                                  if (window != null && window.isNotEmpty) {
                                    final ok = window == dayPart;
                                    chips.add(Chip(label: Text('${window} only (${ok ? 'OK' : 'Wait'})')));
                                  }
                                }
                              } catch (_) {}
                              return chips;
                            }(),
                          )
                        ],
                      ],
                    ),
                    trailing: (holdings[offer.drugId] ?? 0) > 0
                        ? const Chip(label: Text('In stock'))
                        : null,
                    onTap: () async {
                      if (offer.customerType == 'VIP') {
                        await _showVipModal(context, ref, offer);
                        return;
                      }
                      final matches = prices.where((e) => e['drug'].id == offer.drugId);
                      final base = matches.isEmpty ? 0 : (matches.first['drug'] as dynamic).basePrice as int;
                      final isBigDeal = offer.risk < 0.1 || offer.priceOffer > 2 * base;
                      await showDialog(
                        context: context,
                        builder: (_) => DealModal(offer: offer),
                      );
                      if (isBigDeal) {
                        setState(() => _showConfetti = true);
                        await Future.delayed(const Duration(milliseconds: 1200));
                        setState(() => _showConfetti = false);
                      }
                    },
                  ),
                )),
          ],
        ),
  if (_showConfetti) const Positioned.fill(child: AnimatedConfetti(trigger: true)),
      ],
    );
  }

  void _showBuyDialog(BuildContext context, String drugId, String drugName, int unitPrice) {
    final gs = ref.read(gameStateProvider);
    final cash = gs['cash'] as int;
    final invRaw = gs['inventory'];
    final inv = invRaw is Map ? Map<String, dynamic>.from(invRaw) : <String, dynamic>{};
    final holdings = Inventory.fromJson(inv).drugs;
  final totalHeld = holdings.values.fold<int>(0, (a, b) => a + b);
    final upgradesRaw = gs['upgrades'];
    final upgrades = upgradesRaw is Map ? Map<String, dynamic>.from(upgradesRaw) : <String, dynamic>{};
    final safehouse = (upgrades['safehouse'] ?? 0) as int;
    final metaRaw = gs['meta'];
    final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
    final districtBonus = (meta['districtStorageBonus'] ?? 0) as int;
    final capacity = 50 + safehouse * 50 + districtBonus;
    final spaceLeft = (capacity - totalHeld).clamp(0, capacity);
    final maxByCash = unitPrice <= 0 ? 0 : (cash ~/ unitPrice);
    final maxQty = [spaceLeft, maxByCash].reduce((a, b) => a < b ? a : b);
    final ctrl = TextEditingController(text: maxQty > 0 ? '1' : '0');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Buy $drugName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Price: \$${unitPrice} each'),
            const SizedBox(height: 8),
            Text('Capacity left: ${spaceLeft}'),
            Text('Max you can buy now: ${maxQty}'),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: maxQty > 0
                ? () {
                    final qty = maxQty;
                    final total = qty * unitPrice;
                    ref.read(gameStateProvider.notifier).buy(drugId, qty, total);
                    Navigator.of(context).pop();
                    SnackbarService.show(context, 'Bought ${qty} $drugName for \$${total}');
                  }
                : null,
            child: const Text('Buy Max'),
          ),
          ElevatedButton(
            onPressed: () {
              final q = int.tryParse(ctrl.text.trim()) ?? 0;
              final qty = q.clamp(0, maxQty);
              if (qty > 0) {
                final total = qty * unitPrice;
                ref.read(gameStateProvider.notifier).buy(drugId, qty, total);
                Navigator.of(context).pop();
                SnackbarService.show(context, 'Bought ${qty} $drugName for \$${total}');
              }
            },
            child: const Text('Buy'),
          ),
        ],
      ),
    );
  }

  String _flavorText(String type) {
    switch (type) {
      case 'Loyal':
        return '"I always come back. Keep it quiet."';
      case 'Whale':
        return '"Money is no object. Impress me!"';
      case 'Sketchy':
        return '"Don\'t ask questions. Just hurry."';
      default:
        return '';
    }
  }

  Future<void> _showVipModal(BuildContext context, WidgetRef ref, Offer offer) async {
    final gs = ref.read(gameStateProvider);
    final day = gs['day'] as int;
    final minDaily = (offer.qty / 2).clamp(1, 50).round();
    final term = 5;
    final bonus = 1.2; // 20% better price
  final curDid = (gs['meta']['currentDistrictId'] ?? '') as String?;
  final restrictId = curDid; // simple UX: default restrict to current district if user wants
  final dayPart = (gs['meta']['dayPart'] ?? 'Day') as String;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('VIP Contract'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Drug: ${offer.drugId}') ,
            Text('Min per day: $minDaily'),
            Text('Term: $term days (until Day ${day + term})'),
            Text('Bonus price: +${((bonus - 1) * 100).round()}% on sales to VIP client'),
      const SizedBox(height: 8),
      const Text('Advanced constraints:'),
      Text('• Route: Current district only'),
      Text('• Time: ${dayPart} only'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final metaRaw = gs['meta'];
              final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
              final vipList = (meta['vipContracts'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? <Map<String, dynamic>>[];
              vipList.add({
                'drugId': offer.drugId,
                'minDaily': minDaily,
                'contractedUntilDay': day + term,
                'priceBonus': bonus,
        if (restrictId != null && restrictId.isNotEmpty) 'restrictDistrictId': restrictId,
        'window': dayPart,
              });
              ref.read(gameStateProvider.notifier).setVipContractsJson(vipList);
              Navigator.of(context).pop();
              SnackbarService.show(context, 'VIP contract accepted.');
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }
}
