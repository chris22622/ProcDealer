import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/types.dart';
import '../core/rng.dart';
import '../core/balance.dart';
import 'game_state.dart';
import 'city_provider.dart';
import 'market_provider.dart';

class CrewState {
  final List<CrewMember> crew;
  final List<CrewMember> candidates;
  CrewState({required this.crew, required this.candidates});
  CrewState copyWith({List<CrewMember>? crew, List<CrewMember>? candidates}) =>
      CrewState(crew: crew ?? this.crew, candidates: candidates ?? this.candidates);
}

class CrewController extends StateNotifier<CrewState> {
  final Ref _ref;
  CrewController(this._ref, CrewState initial) : super(initial) {
    // Hydrate existing crew from GameState.meta if present
    try {
      final metaRaw = _ref.read(gameStateProvider.select((s) => s['meta']));
      final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
      final list = (meta['crew'] as List<dynamic>?)?.map((e) => CrewMember.fromJson(Map<String, dynamic>.from(e))).toList() ?? const <CrewMember>[];
      if (list.isNotEmpty) {
        state = state.copyWith(crew: list);
      }
      // Apply any pending jail time from court resolutions
      final addsRaw = meta['crewJailAddById'];
      final Map<String, int> adds = addsRaw is Map
          ? Map<String, int>.from(addsRaw.map((k, v) => MapEntry(k.toString(), (v as num).toInt())))
          : <String, int>{};
      if (adds.isNotEmpty) {
        final updated = state.crew
            .map((m) => adds.containsKey(m.id)
                ? CrewMember(
                    id: m.id,
                    role: m.role,
                    skill: m.skill,
                    wage: m.wage,
                    fatigue: m.fatigue,
                    morale: m.morale,
                    assignedDistrictId: m.assignedDistrictId,
                    strategy: m.strategy,
                    status: 'arrested',
                    arrestedDays: (m.arrestedDays + (adds[m.id] ?? 0)).clamp(0, 3650),
                    lifetimeEarned: m.lifetimeEarned,
                    todayEarned: m.todayEarned,
                  )
                : m)
            .toList();
        state = state.copyWith(crew: updated);
        _persistCrew();
        // Clear the pending adds from GameState
        try { _ref.read(gameStateProvider.notifier).consumeCrewJailAdds(); } catch (_) {}
      }
      Future.microtask(_updateWagesDue);
    } catch (_) {}
  }
  void hire(String id) {
    // Prevent duplicate hires and handle missing candidate safely
    if (state.crew.any((c) => c.id == id)) return;
    final idx = state.candidates.indexWhere((c) => c.id == id);
    if (idx < 0) return;
    final cand = state.candidates[idx];
    state = CrewState(
      crew: [
        ...state.crew,
        CrewMember(id: cand.id, role: cand.role, skill: cand.skill, wage: cand.wage, fatigue: 0, morale: 65),
      ],
      candidates: [
        ...state.candidates.take(idx),
        ...state.candidates.skip(idx + 1),
      ],
    );
    _persistCrew();
    _updateWagesDue();
  }
  void fire(String id) {
    final idx = state.crew.indexWhere((c) => c.id == id);
    if (idx < 0) return;
    final member = state.crew[idx];
    state = CrewState(
      crew: [
        ...state.crew.take(idx),
        ...state.crew.skip(idx + 1),
      ],
      candidates: [
        ...state.candidates,
        CrewMember(
            id: member.id,
            role: member.role,
            skill: member.skill,
            wage: member.wage,
            fatigue: member.fatigue,
            morale: (member.morale - 5).clamp(0, 100)),
      ],
    );
    _persistCrew();
    _updateWagesDue();
  }

  void _persistCrew() {
    try {
      final list = state.crew.map((m) => m.toJson()).toList();
      _ref.read(gameStateProvider.notifier).setCrewJson(list);
    } catch (_) {}
  }

  void _updateWagesDue() {
    final total = state.crew.fold<int>(0, (a, b) => a + b.wage);
    // sync into game state's meta
    Future.microtask(() => _ref.read(gameStateProvider.notifier).setWagesDue(total));
  }

  void applyFatigue(String role, int amount) {
    state = CrewState(
      crew: state.crew
          .map((c) => c.role == role
              ? CrewMember(id: c.id, role: c.role, skill: c.skill, wage: c.wage, fatigue: (c.fatigue + amount).clamp(0, 100), morale: c.morale)
              : c)
          .toList(),
      candidates: state.candidates,
    );
    _persistCrew();
  }

  void restAll() {
    state = CrewState(
      crew: state.crew
          .map((c) => CrewMember(id: c.id, role: c.role, skill: c.skill, wage: c.wage, fatigue: (c.fatigue - 40).clamp(0, 100), morale: (c.morale + 5).clamp(0, 100)))
          .toList(),
      candidates: state.candidates,
    );
    _persistCrew();
  }

  void train(String id) {
    // simple: costs cash, adds small skill increase capped at 5, boosts morale, adds fatigue
    final gs = _ref.read(gameStateProvider);
    if ((gs['cash'] as int) < 100) return; // need cash
    final idx = state.crew.indexWhere((c) => c.id == id);
    if (idx < 0) return;
    final member = state.crew[idx];
    final newSkill = (member.skill + 1).clamp(1, 5);
    final newMorale = (member.morale + 8).clamp(0, 100);
    final newFatigue = (member.fatigue + 20).clamp(0, 100);
    state = CrewState(
      crew: [
        ...state.crew.take(idx),
        CrewMember(id: member.id, role: member.role, skill: newSkill, wage: member.wage, fatigue: newFatigue, morale: newMorale),
        ...state.crew.skip(idx + 1),
      ],
      candidates: state.candidates,
    );
    // charge cash
    _ref.read(gameStateProvider.notifier).spendCash(100);
    _persistCrew();
    _updateWagesDue();
  }

  // Assign a member to operate in a district (null => current district) and set strategy
  void assign(String id, {String? districtId, String? strategy}) {
    state = state.copyWith(
      crew: state.crew
          .map((c) => c.id == id
              ? CrewMember(
                  id: c.id,
                  role: c.role,
                  skill: c.skill,
                  wage: c.wage,
                  fatigue: c.fatigue,
                  morale: c.morale,
                  assignedDistrictId: districtId ?? c.assignedDistrictId,
                  strategy: strategy ?? c.strategy,
                  status: c.status,
                  arrestedDays: c.arrestedDays,
                  lifetimeEarned: c.lifetimeEarned,
                  todayEarned: c.todayEarned,
                )
              : c)
          .toList(),
    );
    _persistCrew();
  }

  // Daily simulation: crew attempts to sell a limited number of units based on role/skill/fatigue.
  // Returns a summary map to be merged into game meta by game_state.endDay
  Map<String, dynamic> simulateDay() {
    final gs = _ref.read(gameStateProvider);
    final metaRaw = gs['meta'];
    final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
    final city = _ref.read(cityProvider);
    final prices = _ref.read(marketProvider);
    final invRaw = gs['inventory'];
    final invMap = invRaw is Map ? Map<String, dynamic>.from(invRaw) : <String, dynamic>{};
    final inv = Inventory.fromJson(invMap);
    final rng = Rng(((gs['day'] as int) * 1337) + (((meta['brandRep'] ?? 50) as num).toInt()));
    // Compute a conservative working reserve for end-of-day obligations (wages, maintenance, insurance, loan mins)
  int workingReserve() {
      try {
        final metaNow = _ref.read(gameStateProvider)['meta'] as Map<String, dynamic>;
    final crewAutoRaw = metaNow['crewAuto'];
    final crewAuto = crewAutoRaw is Map ? Map<String, dynamic>.from(crewAutoRaw) : const <String, dynamic>{};
        final wages = ((metaNow['wagesDue'] ?? 0) as num).toInt();
        // Maintenance approximation from upgrades (matches endDay structure sans capacity add-on)
        final upRaw = _ref.read(gameStateProvider)['upgrades'];
        final up = upRaw is Map ? Map<String, dynamic>.from(upRaw) : <String, dynamic>{};
        int maintenance = ((up['vehicle'] ?? 0) as int) * 3 + ((up['safehouse'] ?? 0) as int) * 5 + ((up['scanner'] ?? 0) as int) * 2 + ((up['burner'] ?? 0) as int) * 2;
        // Insurance premium if enabled
        final insuranceEnabled = (metaNow['insuranceEnabled'] ?? false) == true;
        final insurancePremium = ((metaNow['insurancePremium'] ?? 50) as num).toInt().clamp(0, 1000000);
        final ins = insuranceEnabled ? insurancePremium : 0;
        // Loan minimum payments (mirror endDay logic)
        int loanMins = 0;
        try {
          final loans = (metaNow['loans'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? const <Map<String, dynamic>>[];
          for (final l in loans) {
            final bal = ((l['balance'] ?? 0) as num).toDouble();
            if (bal <= 0) continue;
            final minByRate = (bal * Balance.loanMinPaymentRate).round();
            final minPay = minByRate < Balance.loanMinPaymentBase ? Balance.loanMinPaymentBase : minByRate;
            loanMins += minPay;
          }
        } catch (_) {}
  // Safety cushion from settings
  final cushion = ((crewAuto['reserveCushion'] ?? 60) as num).toInt().clamp(0, 1000000);
        return (wages + maintenance + ins + loanMins + cushion).clamp(0, 1 << 30);
      } catch (_) {
        return 100; // fallback buffer
      }
    }
    // Estimate crew selling premium vs raw market price (Fixer skill + brand)
    double sellingPremiumFactor() {
      try {
        final bestFixer = state.crew
            .where((c) => c.role == 'Fixer')
            .fold<int>(0, (a, b) => a > b.skill ? a : b.skill);
        final brandRep = ((meta['brandRep'] ?? 50) as num).toInt();
        final fixerBonus = (bestFixer * 0.0025).clamp(0.0, 0.18); // up to ~18%
        final brandBonus = ((brandRep - 50) / 2000.0).clamp(-0.02, 0.03);
        return (1.0 + fixerBonus + brandBonus).clamp(0.95, 1.22);
      } catch (_) {
        return 1.0;
      }
    }
    int netUnitSalePrice(int marketUnit, {required String districtId}) {
      double gross = marketUnit * sellingPremiumFactor();
      try {
        final homeDid = (meta['homeDistrictId'] ?? '') as String;
        final isHome = homeDid.isNotEmpty && districtId == homeDid;
        if (!isHome) gross *= 0.95; // 5% tribute when not at home
      } catch (_) {}
      return gross.round();
    }
  // Autopilot: buy inventory if enabled
    try {
      final autoRaw = meta['crewAuto'];
      final auto = autoRaw is Map ? Map<String, dynamic>.from(autoRaw) : const <String, dynamic>{};
      final enabled = (auto['enabled'] ?? false) as bool;
      if (enabled) {
        final targetUnits = ((auto['targetUnits'] ?? 30) as num).toInt().clamp(0, 10000);
        final maxSpendPct = ((auto['maxSpendPctCash'] ?? 60) as num).toInt().clamp(0, 100);
        final maxWithdraw = ((auto['maxWithdrawPerDay'] ?? 500) as num).toInt().clamp(0, 1000000);
        final strat = (auto['strategy'] ?? 'value') as String;
  // Compute current and capacity
        int held = inv.drugs.values.fold<int>(0, (a, b) => a + b);
        final needed = (targetUnits - held).clamp(0, targetUnits);
        if (needed > 0) {
          // Price list and sort according to strategy
          final priceById = {for (final p in prices) (p['drug'].id as String): (p['price'] as int)};
          final entries = priceById.entries.toList();
          entries.removeWhere((e) => e.value <= 0);
          entries.sort((a, b) {
            switch (strat) {
              case 'expensive':
                return b.value.compareTo(a.value);
              case 'balanced':
                return (a.value - ((inv.drugs[a.key] ?? 0) * 2)).compareTo(b.value - ((inv.drugs[b.key] ?? 0) * 2));
              default:
                return a.value.compareTo(b.value);
            }
          });
          int spendCap = (((gs['cash'] as int) * maxSpendPct) / 100).floor();
          int spent = 0;
          int withdrawnGross = 0;
          final reserve = workingReserve();
          // Margin-aware candidate list (only buy if expected net sale beats buy price by a threshold)
          final String curDid = ((meta['currentDistrictId'] ?? '') as String).isNotEmpty
              ? (meta['currentDistrictId'] as String)
              : (() {
                  final idx = (meta['currentDistrict'] ?? 0) as int;
                  return (idx >= 0 && idx < city.districts.length) ? city.districts[idx].id : (city.districts.isEmpty ? '' : city.districts.first.id);
                })();
          final double minMarginPct = (((auto['minMarginPct'] ?? 7) as num).toDouble().clamp(0, 100)) / 100.0;
          final profitable = entries
              .map((e) {
                final buy = e.value;
                final expSell = netUnitSalePrice(e.value, districtId: curDid);
                final margin = expSell - buy;
                final pct = buy > 0 ? (margin / buy) : -1.0;
                return {'drugId': e.key, 'buy': buy, 'expSell': expSell, 'pct': pct};
              })
              .where((m) => (m['pct'] as double) >= minMarginPct)
              .toList()
            ..sort((a, b) {
              // prioritize by margin pct; tie-break by expected sell price
              final ap = a['pct'] as double;
              final bp = b['pct'] as double;
              if (bp.compareTo(ap) != 0) return bp.compareTo(ap);
              return (b['expSell'] as int).compareTo(a['expSell'] as int);
            });
          // Buy loop across profitable list
          int boughtUnits = 0;
          for (final m in profitable) {
            if (boughtUnits >= needed) break;
            final price = m['buy'] as int;
            final String drugId = m['drugId'] as String;
            // Ensure reserve cash remains after this buy; if not, try withdrawing gross to cover shortfall
            while (boughtUnits < needed) {
              final gsNow = _ref.read(gameStateProvider);
              final cashNow = (gsNow['cash'] as int);
              final bankNow = ((gsNow['meta']?['bank'] ?? 0) as int);
              final maxLeft = (maxWithdraw - withdrawnGross).clamp(0, maxWithdraw);
              final bool canAffordWithReserve = (cashNow - spent - price) >= reserve;
              final bool smartBanking = (auto['smartBanking'] ?? true) as bool;
              if (smartBanking && !canAffordWithReserve && bankNow > 0 && maxLeft > 0) {
                // Compute gross needed so that net after fee meets the shortfall + a tiny headroom
                final shortfall = reserve + price - (cashNow - spent);
                if (shortfall <= 0) break; // shouldn't happen
                // gross - fee(gross) >= shortfall
                int gross = shortfall + Balance.bankWithdrawMinFee;
                int fee(int g) => (g * Balance.bankWithdrawFeeRate).round().clamp(Balance.bankWithdrawMinFee, g);
                while (gross - fee(gross) < shortfall && gross < shortfall + 2000) { gross += 1; }
                gross = gross.clamp(0, bankNow).clamp(0, maxLeft);
                if (gross <= 0) break;
                _ref.read(gameStateProvider.notifier).withdrawBank(gross);
                withdrawnGross += gross;
                try {
                  _ref.read(gameStateProvider.notifier).queueNextDayEvents([
                    {'type': 'Crew', 'desc': 'Crew withdrew \$${gross} to restock.'}
                  ]);
                } catch (_) {}
                // Recompute spendCap from new cash
                final gs2 = _ref.read(gameStateProvider);
                spendCap = (((gs2['cash'] as int) * maxSpendPct) / 100).floor();
                continue; // re-evaluate afford check
              }
              // Respect spendCap budget and reserve
              if ((spent + price) > spendCap) break;
              if (!canAffordWithReserve) break;
              // Execute buy
              _ref.read(gameStateProvider.notifier).buy(drugId, 1, price);
              spent += price;
              boughtUnits += 1;
              inv.drugs[drugId] = (inv.drugs[drugId] ?? 0) + 1;
              // If next unit would violate reserve/spendCap, break inner loop
              final nextCash = (_ref.read(gameStateProvider)['cash'] as int);
              if ((spent + price) > spendCap || (nextCash - spent - price) < reserve) break;
            }
            final cashCheck = (_ref.read(gameStateProvider)['cash'] as int);
            if ((cashCheck - spent) < (profitable.isNotEmpty ? (profitable.first['buy'] as int) : 0)) break;
          }
          if (boughtUnits > 0) {
            // Log
            try {
              _ref.read(gameStateProvider.notifier).queueNextDayEvents([
                {'type': 'Crew', 'desc': 'Crew restocked ${boughtUnits}u (profit-targeted).'}
              ]);
            } catch (_) {}
          } else {
            // No profitable buys
            try {
              _ref.read(gameStateProvider.notifier).queueNextDayEvents([
                {'type': 'Crew', 'desc': 'Crew skipped restock (no profitable buys).'}
              ]);
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  // Optional: Profit-aware auto-travel to a better district before selling
    String? forcedDistrictId;
    try {
      final autoRaw = meta['crewAuto'];
      final auto = autoRaw is Map ? Map<String, dynamic>.from(autoRaw) : const <String, dynamic>{};
      final bool autoTravel = (auto['autoTravel'] ?? true) as bool;
      if (autoTravel) {
        // Gather current context
        final city = _ref.read(cityProvider);
        final idxCur = (meta['currentDistrict'] ?? 0) as int;
        final String curDid = ((meta['currentDistrictId'] ?? '') as String).isNotEmpty
            ? (meta['currentDistrictId'] as String)
            : (idxCur >= 0 && idxCur < city.districts.length ? city.districts[idxCur].id : (city.districts.isEmpty ? '' : city.districts.first.id));
        final double curBonus = (city.bonuses[curDid]?['priceMod'] ?? 0).toDouble();
        // Price map for current district
        final priceById = {for (final p in prices) (p['drug'].id as String): (p['price'] as int)};
        // Held units and current total value
        final int heldUnits = inv.drugs.values.fold<int>(0, (a, b) => a + b);
        final int totalValueNow = inv.drugs.entries.fold<int>(0, (a, e) => a + (priceById[e.key] ?? 0) * e.value);
        // Estimate sell capacity today (sum of member capacities if not arrested)
        int totalCap = 0;
        for (final m in state.crew) {
          if (m.arrestedDays > 0) continue;
          final baseCap = 3 + m.skill;
          final fatiguePenalty = (m.fatigue / 25).floor();
          totalCap += (baseCap - fatiguePenalty).clamp(1, baseCap);
        }
        final int willSell = heldUnits == 0 ? 0 : (totalCap.clamp(0, heldUnits));
        if (willSell > 0 && totalValueNow > 0 && city.districts.length > 1) {
          // Driver/vehicle context for travel cost and heat
          final vehicle = (gs['upgrades']['vehicle'] ?? 0) as int;
          final driverSkill = state.crew.where((c) => c.role == 'Driver').map((c) => c.skill).fold<int>(0, (a, b) => a > b ? a : b);
          final driverFatigueAvg = () {
            final list = state.crew.where((c) => c.role == 'Driver').toList();
            if (list.isEmpty) return 0.0;
            return list.map((c) => c.fatigue).reduce((a, b) => a + b) / list.length;
          }();
          int bestIdx = idxCur;
          double bestScore = 0.0;
          double bestHeat = 0.0;
          int bestCost = 0;
          final reserve = workingReserve();
          for (int i = 0; i < city.districts.length; i++) {
            if (i == idxCur) continue;
            final did = city.districts[i].id;
            final double bonus = (city.bonuses[did]?['priceMod'] ?? 0).toDouble();
            final double delta = bonus - curBonus; // price advantage
            if (delta <= 0.0) continue; // only consider better-than-current
            // Revenue improvement estimate
            final double priceMult = 1.0 + delta;
            final double currentRevenue = (totalValueNow * (willSell / (heldUnits == 0 ? 1 : heldUnits))).toDouble();
            final double candRevenue = currentRevenue * priceMult;
            final double gain = candRevenue - currentRevenue;
            // Travel cost and heat (match UI computation)
            final hops = shortestHops(city, idxCur, i);
            final hopFactor = (hops <= 0 ? 1.0 : 1.0 + 0.5 * hops);
            final baseCost = 35.0;
            final baseHeat = 0.12;
            final costFatigueMult = 1.0 + (driverFatigueAvg / 100.0) * 0.05;
            int cost = (baseCost * hopFactor * (1.0 - 0.12 * vehicle) * costFatigueMult).round().clamp(5, 300);
            final police = city.districts[i].policePresence;
            double heatInc = (baseHeat * hopFactor * (0.9 + 0.5 * police)).clamp(0.0, 0.35);
            heatInc *= (1.0 - 0.06 * vehicle).clamp(0.6, 1.0);
            final driverMod = (1.0 - 0.07 * driverSkill + (driverFatigueAvg / 100.0) * 0.05).clamp(0.5, 1.1);
            heatInc *= driverMod;
            // Simple risk penalty for heavy police/pressure
            double riskPenalty = police * 10.0;
            try {
              final ppRaw = meta['policePressureByDid'];
              final Map<String, int> pp = ppRaw is Map ? Map<String, int>.from(ppRaw.map((k, v) => MapEntry(k.toString(), (v as num).toInt()))) : <String, int>{};
              final daysLeft = (pp[did] ?? 0).clamp(0, 3);
              riskPenalty += daysLeft * 8.0;
            } catch (_) {}
            final double score = gain - cost - riskPenalty;
            if (score > bestScore) {
              bestScore = score;
              bestIdx = i;
              bestHeat = heatInc;
              bestCost = cost;
            }
          }
          // Only travel if we can afford it and still keep reserve
          if (bestIdx != idxCur && bestScore > 25.0 && ((_ref.read(gameStateProvider)['cash'] as int) - bestCost) >= reserve) {
            final target = city.districts[bestIdx];
            // Move via GameState so cash/heat apply
            _ref.read(gameStateProvider.notifier).travel(bestCost, bestHeat,
                toDistrictIndex: bestIdx, toDistrictId: target.id,
                heatDecayBonus: (city.bonuses[target.id]?['heatDecayBonus'] as dynamic)?.toDouble(),
                storageBonus: (city.bonuses[target.id]?['storageBonus'] as dynamic)?.toInt());
            forcedDistrictId = target.id;
            // Log event for recap (queue into GameState next-day events to avoid local scope issue)
            try {
              _ref.read(gameStateProvider.notifier).queueNextDayEvents([
                {'type': 'Crew', 'desc': 'Crew auto-traveled to ${target.name} (-\$${bestCost}).'}
              ]);
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
    int bankCredit = 0;
    double heatGen = 0.0;
    int conflictCost = 0;
    int unitsSold = 0;
    final soldByDrug = <String, int>{};
    final soldByDD = <String, int>{};
    final events = <Map<String, dynamic>>[];
    final updatedCrew = <CrewMember>[];
    final perMember = <Map<String, dynamic>>[];
  for (final m in state.crew) {
      // decrement arrest timers
      if (m.arrestedDays > 0) {
        updatedCrew.add(CrewMember(
          id: m.id,
          role: m.role,
          skill: m.skill,
          wage: m.wage,
          fatigue: (m.fatigue - 20).clamp(0, 100),
          morale: (m.morale - 2).clamp(0, 100),
          assignedDistrictId: m.assignedDistrictId,
          strategy: m.strategy,
          status: 'arrested',
          arrestedDays: (m.arrestedDays - 1).clamp(0, 10),
          lifetimeEarned: m.lifetimeEarned,
          todayEarned: 0,
        ));
        perMember.add({'id': m.id, 'role': m.role, 'earned': 0});
        continue;
      }
      // Work capacity influenced by skill and fatigue
      final baseCap = 3 + m.skill; // 4..8 units
      final fatiguePenalty = (m.fatigue / 25).floor();
      int capacity = (baseCap - fatiguePenalty).clamp(1, baseCap);
      // Choose a district
  String did = forcedDistrictId ?? m.assignedDistrictId ?? (meta['currentDistrictId'] as String? ?? '');
      if (did.isEmpty) {
        final idx = (meta['currentDistrict'] ?? 0) as int;
        if (idx >= 0 && idx < city.districts.length) did = city.districts[idx].id;
      }
      // Strategy picks best from available inventory
      final available = inv.drugs.entries.where((e) => (e.value > 0)).toList();
      if (available.isEmpty) {
        updatedCrew.add(CrewMember(
          id: m.id,
          role: m.role,
          skill: m.skill,
          wage: m.wage,
          fatigue: (m.fatigue - 20).clamp(0, 100),
          morale: (m.morale - 1).clamp(0, 100),
          assignedDistrictId: m.assignedDistrictId,
          strategy: m.strategy,
          status: 'idle',
          arrestedDays: 0,
          lifetimeEarned: m.lifetimeEarned,
          todayEarned: 0,
        ));
        // Recap hint for why no revenue was generated
  events.add({'day': gs['day'], 'type': 'Crew', 'desc': '${m.role} had nothing to sell today.'});
        perMember.add({'id': m.id, 'role': m.role, 'earned': 0});
        continue;
      }
      // Map prices by drug id
      final priceById = {for (final p in prices) (p['drug'].id as String): (p['price'] as int)};
      // Sort candidates by strategy
      available.sort((a, b) {
        final pa = priceById[a.key] ?? 0;
        final pb = priceById[b.key] ?? 0;
        switch (m.strategy) {
          case 'greedy':
            return pb.compareTo(pa); // highest price first
          case 'lowrisk':
            return a.value.compareTo(b.value); // smaller stacks first
          default: // balanced
            return (pb * 0.7 + b.value * 0.3).compareTo(pa * 0.7 + a.value * 0.3);
        }
      });
      // Try to sell up to capacity units across top 2 picks
      int earnedToday = 0;
      int used = 0;
      String districtName = '';
      for (final candidate in available.take(2)) {
        if (used >= capacity) break;
        final drugId = candidate.key;
        final have = candidate.value;
        final unitPrice = priceById[drugId] ?? 0;
        if (unitPrice <= 0 || have <= 0) continue;
        final qty = (capacity - used).clamp(0, have);
        if (qty <= 0) continue;
  // Apply selling premium and tribute to compute net unit revenue
  final int priceNet = netUnitSalePrice(unitPrice, districtId: did);
        final revenue = priceNet * qty;
        earnedToday += revenue;
        used += qty;
        unitsSold += qty;
        soldByDrug[drugId] = (soldByDrug[drugId] ?? 0) + qty;
        soldByDD['did_${did}_$drugId'] = (soldByDD['did_${did}_$drugId'] ?? 0) + qty;
        // Deduct from shared inventory
        final cur = inv.drugs[drugId] ?? 0;
        inv.drugs[drugId] = (cur - qty).clamp(0, cur);
        // Heat from activity weighted by district police presence and member role
        try {
          final d = city.districts.firstWhere((x) => x.id == did);
          districtName = d.name;
          final baseHeat = 0.01 + d.policePresence * 0.02; // 1%..3%
          final roleMod = m.role == 'Fixer' ? 0.8 : 1.0;
          heatGen += baseHeat * roleMod * qty;
        } catch (_) {}
      }
      // Conflict chance: small chance to trigger beef costs
      if (earnedToday > 0) {
        final p = (0.03 + (m.morale < 50 ? 0.02 : 0) + (m.fatigue > 70 ? 0.02 : 0)).clamp(0.0, 0.12);
        if (rng.nextDoubleRange(0, 1) < p) {
          // conflict fine damages your brand and costs some cash (later pulled from nightly)
          final cost = rng.nextIntRange(20, 80);
          conflictCost += cost;
          if (districtName.isEmpty) {
            try {
              final d = city.districts.firstWhere((x) => x.id == did);
              districtName = d.name;
            } catch (_) {}
          }
          events.add({'day': gs['day'], 'type': 'Crew', 'desc': 'Crew beef in ${districtName.isEmpty ? 'the city' : districtName}: -\$${cost}'});
        }
      }
      // Arrest chance: increases with police presence and global heat
      bool arrested = false;
      try {
        final d = city.districts.firstWhere((x) => x.id == did);
        final heat = ((gs['heat'] ?? 0.0) as num).toDouble();
        // Temporary police pressure increases arrest chance slightly per active day
        double pressureBoost = 0.0;
        try {
          final metaRaw2 = gs['meta'];
          final meta2 = metaRaw2 is Map ? Map<String, dynamic>.from(metaRaw2) : <String, dynamic>{};
          final ppRaw = meta2['policePressureByDid'];
          final pp = ppRaw is Map ? Map<String, dynamic>.from(ppRaw) : <String, dynamic>{};
          final daysLeft = (pp[did] ?? 0) as int;
          if (daysLeft > 0) pressureBoost = 0.02 * daysLeft.clamp(0, 3); // up to +6%
        } catch (_) {}
        final pArrest = (0.01 + d.policePresence * 0.03 + heat * 0.05 + pressureBoost + (m.role == 'Driver' ? -0.005 : 0)).clamp(0.0, 0.24);
  if (used > 0 && rng.nextDoubleRange(0, 1) < pArrest) {
          arrested = true;
          final days = rng.nextIntRange(1, 3);
          events.add({'day': gs['day'], 'type': 'Arrest', 'desc': '${m.role} picked up in ${d.name}. Out for ${days}d.'});
          // Update crew as arrested below
          updatedCrew.add(CrewMember(
            id: m.id,
            role: m.role,
            skill: m.skill,
            wage: m.wage,
            fatigue: (m.fatigue + 10).clamp(0, 100),
            morale: (m.morale - 10).clamp(0, 100),
            assignedDistrictId: m.assignedDistrictId,
            strategy: m.strategy,
            status: 'arrested',
            arrestedDays: days,
            lifetimeEarned: m.lifetimeEarned + earnedToday,
            todayEarned: earnedToday,
          ));
          // File a legal case for this arrest
          try {
            final caseJson = {
              'id': 'C${DateTime.now().millisecondsSinceEpoch}_${m.id}',
              'type': 'crew',
              'crewId': m.id,
              'severity': (d.policePresence >= 0.7) ? 3 : (d.policePresence >= 0.4 ? 2 : 1),
              'bail': 50 + (25 * days),
              'daysUntilHearing': 2 + rng.nextIntRange(0, 2),
              'status': 'open',
              'fineOnConviction': 100 + rng.nextIntRange(0, 100),
              'jailDaysOnConviction': days + rng.nextIntRange(0, 3),
            };
            _ref.read(gameStateProvider.notifier).addLegalCase(caseJson);
          } catch (_) {}
        }
      } catch (_) {}
      bankCredit += earnedToday;
      // Fatigue and morale update
      final nf = (m.fatigue + (used > 0 ? 25 : 10)).clamp(0, 100);
      final nm = (m.morale + (used > 0 ? 2 : -1)).clamp(0, 100);
      if (!arrested) {
        updatedCrew.add(CrewMember(
          id: m.id,
          role: m.role,
          skill: m.skill,
          wage: m.wage,
          fatigue: nf,
          morale: nm,
          assignedDistrictId: m.assignedDistrictId,
          strategy: m.strategy,
          status: used > 0 ? 'selling' : 'idle',
          arrestedDays: 0,
          lifetimeEarned: m.lifetimeEarned + earnedToday,
          todayEarned: earnedToday,
        ));
      }
      perMember.add({'id': m.id, 'role': m.role, 'earned': earnedToday});
    }
    // Save crew updates back into provider state and persist
    state = state.copyWith(crew: updatedCrew);
    _persistCrew();
    // After buys/travel/sales: deposit any surplus cash above reserve back into bank
    try {
      final reserve = workingReserve();
      final cashNow = (_ref.read(gameStateProvider)['cash'] as int);
      final excess = (cashNow - reserve).clamp(0, cashNow);
      final metaNow = _ref.read(gameStateProvider)['meta'] as Map<String, dynamic>;
      final crewAutoRaw = metaNow['crewAuto'];
      final crewAuto = crewAutoRaw is Map ? Map<String, dynamic>.from(crewAutoRaw) : const <String, dynamic>{};
      final bool smartBanking = (crewAuto['smartBanking'] ?? true) as bool;
      if (smartBanking && excess > 0) {
        _ref.read(gameStateProvider.notifier).depositBank(excess);
        _ref.read(gameStateProvider.notifier).queueNextDayEvents([
          {'type': 'Crew', 'desc': 'Crew deposited \$${excess} working surplus.'}
        ]);
      }
    } catch (_) {}
    return {
      'bankCredit': bankCredit,
      'heatGen': heatGen,
      'conflictCost': conflictCost,
      'unitsSold': unitsSold,
      'soldByDrug': soldByDrug,
      'soldByDistrictDrug': soldByDD,
      'inventory': Inventory(drugs: inv.drugs).toJson(),
      if (events.isNotEmpty) 'events': events,
      'memberEarnings': perMember,
    };
  }
}

final crewProvider = StateNotifierProvider<CrewController, CrewState>((ref) {
  final day = ref.watch(gameStateProvider.select((s) => s['day'] as int));
  final rng = Rng(day * 65537);
  const roles = ['Chemist', 'Driver', 'Fixer', 'Lawyer'];
  List<CrewMember> gen(int n) {
    final list = <CrewMember>[];
    // Ensure at least one of each role shows up
    for (final r in roles) {
      list.add(CrewMember(
        id: 'cand${day}_${list.length}',
        role: r,
        skill: rng.nextIntRange(1, 5),
        wage: rng.nextIntRange(60, 220),
        fatigue: rng.nextIntRange(0, 10),
        morale: rng.nextIntRange(55, 85),
      ));
    }
    // Fill remaining with random roles
    for (int i = list.length; i < n; i++) {
      final r = roles[rng.nextIntRange(0, roles.length - 1)];
      list.add(CrewMember(
        id: 'cand${day}_$i',
        role: r,
        skill: rng.nextIntRange(1, 5),
        wage: rng.nextIntRange(60, 220),
        fatigue: rng.nextIntRange(0, 10),
        morale: rng.nextIntRange(55, 85),
      ));
    }
    return list;
  }
  final controller = CrewController(ref, CrewState(crew: [], candidates: gen(8)));
  // initialize wagesDue to 0 or existing crew wages
  Future.microtask(controller._updateWagesDue);
  return controller;
});
