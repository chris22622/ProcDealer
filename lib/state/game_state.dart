import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/types.dart';
import '../core/balance.dart';
import '../core/save_service.dart';
import '../data/drug_catalog.dart';
import '../core/rng.dart';

class GameState extends StateNotifier<Map<String, dynamic>> {
  GameState() : super(_loadOrInitial()) {
    // Seed a simple chain if absent and set an initial rumor for tomorrow.
    try {
      final metaRaw = state['meta'];
      final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
      final int day = (state['day'] ?? 1) as int;
      Map<String, dynamic> newMeta = Map<String, dynamic>.from(meta);
      bool changed = false;
      // Seed AI opponents if missing
      if (!newMeta.containsKey('aiOpponents')) {
        newMeta['aiOpponents'] = <Map<String, dynamic>>[
          {
            'id': 'AI_Nyx',
            'name': 'Nyx Syndicate',
            'personality': 'aggressive', // aggressive | economic | legalist
            'budget': 500,
            'heat': 0.35,
          },
          {
            'id': 'AI_Midas',
            'name': 'Midas Crew',
            'personality': 'economic',
            'budget': 500,
            'heat': 0.20,
          },
        ];
        changed = true;
      }
      if (!newMeta.containsKey('aiDifficulty')) {
        newMeta['aiDifficulty'] = 'normal'; // easy | normal | hard
        changed = true;
      }
      if (!newMeta.containsKey('chain')) {
        final steps = [
          {'drugId': drugCatalog[0].id, 'qty': 5, 'reward': 200},
          {'drugId': drugCatalog[1].id, 'qty': 8, 'reward': 300},
          {'drugId': drugCatalog[2].id, 'qty': 12, 'reward': 500},
        ];
        newMeta['chain'] = {
          'active': true,
          'step': 0,
          'steps': steps,
          'createdDay': day,
        };
        changed = true;
      }
      if (!newMeta.containsKey('rumorNext')) {
        final rng = Rng(day * 99991);
        final weights = {
          'Festival': 0.25,
          'Drought': 0.2,
          'Gang War': 0.2,
          'Raid': 0.15,
          'Quiet': 0.2,
        };
        final pick = rng.pickWeighted(weights.keys.toList(), weights.values.toList());
        newMeta['rumorNext'] = {'type': pick, 'day': day + 1};
        changed = true;
      }
      if (changed) {
        state = {
          ...state,
          'meta': newMeta,
        };
        SaveService.autosave(state);
      }
    } catch (_) {}
  }

  // Apply crew autonomous operations into state. Call this before endDay() from UI.
  void applyCrewDay(Map<String, dynamic> crewResult) {
    try {
      final metaRaw = state['meta'];
      final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
      // Merge inventory
      final invNew = crewResult['inventory'] as Map<String, dynamic>?;
      // Track sales and units
      final crewUnits = (crewResult['unitsSold'] ?? 0) as int;
      final soldByDrug = Map<String, int>.from((meta['soldTodayByDrug'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toInt())) ?? {});
      final addByDrug = Map<String, int>.from((crewResult['soldByDrug'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toInt())) ?? {});
      addByDrug.forEach((k, v) => soldByDrug[k] = (soldByDrug[k] ?? 0) + v);
      final soldByDD = Map<String, int>.from((meta['soldByDistrictDrugUnits'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toInt())) ?? {});
      final addByDD = Map<String, int>.from((crewResult['soldByDistrictDrug'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toInt())) ?? {});
      addByDD.forEach((k, v) => soldByDD[k] = (soldByDD[k] ?? 0) + v);
      // Influence gains aggregation
      final inflRaw = meta['influenceByDistrict'];
      final Map<String, int> infl = inflRaw is Map ? Map<String, int>.from(inflRaw.map((k, v) => MapEntry(k.toString(), (v as num).toInt()))) : <String, int>{};
      final incByDid = <String, int>{};
      addByDD.forEach((k, v) {
        if (k.startsWith('did_')) {
          final rest = k.substring(4);
          final idx = rest.indexOf('_');
          if (idx > 0) {
            final did = rest.substring(0, idx);
            incByDid[did] = (incByDid[did] ?? 0) + v;
          }
        }
      });
      incByDid.forEach((did, units) {
        final add = units >= 3 ? ((units / 6.0).round().clamp(1, 8)) : 0;
        if (add > 0) infl[did] = ((infl[did] ?? 0) + add).clamp(0, 100);
      });
      // Credit bank directly with crew revenue
      final credited = (crewResult['bankCredit'] ?? 0) as int;
      // Heat generated
      final crewHeat = ((crewResult['heatGen'] ?? 0.0) as num).toDouble();
      // Conflict costs apply later as maintenance-like cost
      final crewConflict = (crewResult['conflictCost'] ?? 0) as int;
      final extraEvents = (crewResult['events'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? const <Map<String, dynamic>>[];
      // Optional: per-member earnings for recap
      final memberEarnRaw = crewResult['memberEarnings'];
      final List<Map<String, dynamic>> memberEarnings = memberEarnRaw is List
          ? memberEarnRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : const <Map<String, dynamic>>[];
      state = {
        ...state,
        if (invNew != null) 'inventory': invNew,
        'meta': {
          ...meta,
          'soldTodayByDrug': soldByDrug,
          'soldByDistrictDrugUnits': soldByDD,
          if (incByDid.isNotEmpty) 'influenceByDistrict': infl,
          'bank': ((meta['bank'] ?? 0) as int) + credited,
          'bankDeltaToday': ((meta['bankDeltaToday'] ?? 0) as int) + credited,
          'crewBankCreditToday': ((meta['crewBankCreditToday'] ?? 0) as int) + credited,
          'unitsSoldToday': ((meta['unitsSoldToday'] ?? 0) as int) + crewUnits,
          'salesToday': ((meta['salesToday'] ?? 0) as int) + credited,
          'crewConflictToday': ((meta['crewConflictToday'] ?? 0) as int) + crewConflict,
          if (memberEarnings.isNotEmpty)
            'crewEarningsToday': [
              ...(((meta['crewEarningsToday'] as List<dynamic>?) ?? const [])).map((e) => Map<String, dynamic>.from(e)),
              ...memberEarnings,
            ],
          if (extraEvents.isNotEmpty)
            'eventsForDay': [
              ...((meta['eventsForDay'] as List<dynamic>? ?? const [])).map((e) => Map<String, dynamic>.from(e)),
              ...extraEvents,
            ],
        },
        'heat': ((state['heat'] as num).toDouble() + crewHeat).clamp(0, 1.0),
      };
      SaveService.autosave(state);
    } catch (_) {}
  }

  static Map<String, dynamic> _initialState() => {
    'cash': 500,
    'day': 1,
    'heat': 0.0,
    'inventory': Inventory(drugs: {for (var d in drugCatalog) d.id: 0}).toJson(),
    'upgrades': Upgrades().toJson(),
    'fronts': 0,
    'meta': {
      'prestige': 0,
      'brandRep': 50, // 0..100
      'purityBoost': 0,
      'adulterantActive': false,
  'wagesDue': 0,
  'lastWagesPaid': 0,
  'currentDistrict': 0,
  'currentDistrictId': '',
  'homeDistrictId': '',
  'bank': 0,
  'bankCompound': true,
  'creditScore': Balance.creditScoreStart,
  'loans': <Map<String, dynamic>>[], // {id, principal, balance, dailyRate, takenDay}
  'autopayPreferBank': true,
  // added: automation rules baseline
  'auto': {
    'enabled': false,
    'depositAbove': 0,
    'buyMinUnits': 0,
    'buyMaxSpendPct': 40,
  },
  // Crew autopilot
  'crewAuto': {
    'enabled': true,
    'targetUnits': 30,
    'maxSpendPctCash': 60,
    'maxWithdrawPerDay': 500,
    'strategy': 'value', // value | balanced | expensive
  },
  // Rival AI opponents
  'aiOpponents': <Map<String, dynamic>>[],
  'aiDifficulty': 'normal',
  'vipContracts': <Map<String, dynamic>>[],
  'evidence': 0.0,
  'patternByDistrictDrug': <String, int>{},
  'soldByDistrictDrugUnits': <String, int>{},
  'vipMissStreakByDrug': <String, int>{},
  'globalShortages': <Map<String, dynamic>>[],
  'mutationOfWeek': <String, dynamic>{},
  'bribeStreak': 0,
  'dayPart': 'Day',
  // added: turf influence tracking
  'influenceByDistrict': <String, int>{},
  // Temporary pressure by district increasing arrest chance; map did -> days remaining
  'policePressureByDid': <String, int>{},
  // Supplier anti-poach shields; sid -> days remaining
  'supplierShieldById': <String, int>{},
  // Legal system
  'legalCases': <Map<String, dynamic>>[], // list of LegalCase json
  'lawyerRetainer': 0, // reduces conviction chance
  'lawyerQuality': 0, // 0..3 additional reduction
    },
  };

  static Map<String, dynamic> _loadOrInitial() {
    try {
      final saved = SaveService.loadRun();
      if (saved != null) {
        // Basic validation: ensure required keys exist, else fallback
        final hasInv = saved.containsKey('inventory') && saved.containsKey('cash') && saved.containsKey('upgrades');
        if (hasInv) return saved;
      }
    } catch (_) {}
    return _initialState();
  }

  int get cash => state['cash'];
  int get day => state['day'];
  double get heat => state['heat'];
  Inventory get inventory => Inventory.fromJson(
        state['inventory'] is Map ? Map<String, dynamic>.from(state['inventory']) : <String, dynamic>{},
      );
  Upgrades get upgrades => Upgrades.fromJson(
        state['upgrades'] is Map ? Map<String, dynamic>.from(state['upgrades']) : <String, dynamic>{},
      );
  int get fronts => state['fronts'];
  Map<String, dynamic> get meta =>
      state['meta'] is Map ? Map<String, dynamic>.from(state['meta']) : <String, dynamic>{};
  int get bank => (meta['bank'] ?? 0) as int;
  bool get bankCompound => (meta['bankCompound'] ?? true) as bool;

  void adjustBrandRep(int delta) {
    final rep = (meta['brandRep'] ?? 50) as int;
    state = {
      ...state,
      'meta': {
        ...meta,
        'brandRep': (rep + delta).clamp(0, 100),
      }
    };
    SaveService.autosave(state);
  }

  void setAdulterantActive(bool v) {
    state = {
      ...state,
      'meta': {
        ...meta,
        'adulterantActive': v,
      }
    };
    SaveService.autosave(state);
  }

  void setPurityBoost(int val) {
    state = {
      ...state,
      'meta': {
        ...meta,
        'purityBoost': val.clamp(0, 4),
      }
    };
    SaveService.autosave(state);
  }

  void setUpgrades(Upgrades up) {
    state = {
      ...state,
      'upgrades': up.toJson(),
    };
    SaveService.autosave(state);
  }

  void applyUpgrade(Upgrades up, int cost) {
    if (cost <= cash) {
      state = {
        ...state,
        'cash': cash - cost,
        'upgrades': up.toJson(),
      };
      SaveService.autosave(state);
    }
  }

  void setWagesDue(int amount) {
    if (amount < 0) amount = 0;
    state = {
      ...state,
      'meta': {
        ...meta,
        'wagesDue': amount,
      }
    };
    SaveService.autosave(state);
  }

  void setFactions(List<Faction> factions) {
    state = {
      ...state,
      'meta': {
        ...meta,
        'factions': factions.map((f) => f.toJson()).toList(),
      }
    };
    SaveService.autosave(state);
  }

  void setObjectivesJson(List<Map<String, dynamic>> list) {
    state = {
      ...state,
      'meta': {
        ...meta,
        'objectives': list,
      }
    };
    SaveService.autosave(state);
  }

  void setChain(Map<String, dynamic> chain) {
    state = {
      ...state,
      'meta': {
        ...meta,
        'chain': chain,
      }
    };
    SaveService.autosave(state);
  }

  void setVipContracts(List<Map<String, dynamic>> list) {
    state = {
      ...state,
      'meta': {
        ...meta,
        'vipContracts': list,
      }
    };
    SaveService.autosave(state);
  }

  void setContractsJson(List<Map<String, dynamic>> list) {
    state = {
      ...state,
      'meta': {
        ...meta,
        'contracts': list,
      }
    };
    SaveService.autosave(state);
  }
  void setRumorNext(Map<String, dynamic> rumor) {
    state = {
      ...state,
      'meta': {
        ...meta,
        'rumorNext': rumor,
      }
    };
    SaveService.autosave(state);
  }

  void setMutationOfWeek(Map<String, dynamic> m) {
    state = {
      ...state,
      'meta': {
        ...meta,
        'mutationOfWeek': m,
      }
    };
    SaveService.autosave(state);
  }

  void setGlobalShortages(List<Map<String, dynamic>> list) {
    state = {
      ...state,
      'meta': {
        ...meta,
        'globalShortages': list,
      }
    };
    SaveService.autosave(state);
  }

  void setVipContractsJson(List<Map<String, dynamic>> list) {
    state = {
      ...state,
      'meta': {
        ...meta,
        'vipContracts': list,
      }
    };
    SaveService.autosave(state);
  }

  // Persist the crew list in meta for hydration across days
  void setCrewJson(List<Map<String, dynamic>> crew) {
    state = {
      ...state,
      'meta': {
        ...meta,
        'crew': crew,
      }
    };
    SaveService.autosave(state);
  }

  void clearObjectiveBadge() {
    state = {
      ...state,
      'meta': {
        ...meta,
        'objectiveRewarded': false,
      }
    };
    SaveService.autosave(state);
  }

  void payWages(int amount) {
    if (amount <= 0) return;
    state = {
      ...state,
      'cash': cash - amount,
    };
    SaveService.autosave(state);
  }

  // Fresh game (no prestige gain)
  void freshGame() {
    state = _initialState();
    SaveService.autosave(state);
  }

  // Set the home district (and current) once per run. Optionally apply district bonuses.
  void setHomeDistrict({required int index, required String id, double? heatDecayBonus, int? storageBonus}) {
    state = {
      ...state,
      'meta': {
        ...meta,
        'homeDistrictId': id,
        'currentDistrict': index,
        'currentDistrictId': id,
        if (heatDecayBonus != null) 'districtHeatDecayBonus': heatDecayBonus,
        if (storageBonus != null) 'districtStorageBonus': storageBonus,
      }
    };
    SaveService.autosave(state);
  }

  // Keep currentDistrict index/id in sync with today's city without side-effects.
  void setCurrentDistrictContext({required int index, required String id, double? heatDecayBonus, int? storageBonus}) {
    state = {
      ...state,
      'meta': {
        ...meta,
        'currentDistrict': index,
        'currentDistrictId': id,
        if (heatDecayBonus != null) 'districtHeatDecayBonus': heatDecayBonus,
        if (storageBonus != null) 'districtStorageBonus': storageBonus,
      }
    };
    SaveService.autosave(state);
  }

  void spendCash(int amount) {
    if (amount <= 0 || cash < amount) return;
    state = {
      ...state,
      'cash': cash - amount,
    };
    SaveService.autosave(state);
  }

  void depositBank(int amount) {
    if (amount <= 0) return;
    if (cash < amount) return;
    state = {
      ...state,
      'cash': cash - amount,
      'meta': {
        ...meta,
        'bank': bank + amount,
  'bankDeltaToday': (meta['bankDeltaToday'] ?? 0) + amount,
      }
    };
    SaveService.autosave(state);
  }

  void withdrawBank(int amount) {
    if (amount <= 0) return;
    if (bank < amount) return;
    // apply withdrawal fee
    final fee = (amount * Balance.bankWithdrawFeeRate).round().clamp(Balance.bankWithdrawMinFee, amount);
    state = {
      ...state,
      'cash': cash + (amount - fee),
      'meta': {
        ...meta,
        'bank': bank - amount,
        'lastBankFee': fee,
        'bankDeltaToday': (meta['bankDeltaToday'] ?? 0) - amount,
      }
    };
    SaveService.autosave(state);
  }

  // Loans
  void takeLoan(int amount) {
    if (amount <= 0) return;
    final score = (meta['creditScore'] ?? Balance.creditScoreStart) as int;
    final cap = Balance.maxLoanForScore(score);
    if (amount > cap) return;
    // choose rate by score
    final rate = score >= 700
        ? Balance.loanDailyRateGood
        : score >= 600
            ? Balance.loanDailyRateMid
            : Balance.loanDailyRateBad;
    final loans = (meta['loans'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? <Map<String, dynamic>>[];
    final id = 'L${DateTime.now().millisecondsSinceEpoch}';
    loans.add({'id': id, 'principal': amount, 'balance': amount, 'dailyRate': rate, 'takenDay': day});
    state = {
      ...state,
      'cash': cash + amount,
      'meta': {
        ...meta,
        'loans': loans,
        'bankDeltaToday': (meta['bankDeltaToday'] ?? 0) + amount,
      }
    };
    SaveService.autosave(state);
  }

  void repayLoan(String id, int amount) {
    if (amount <= 0 || cash < amount) return;
    final loans = (meta['loans'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? <Map<String, dynamic>>[];
    final idx = loans.indexWhere((l) => l['id'] == id);
    if (idx < 0) return;
    final bal = (loans[idx]['balance'] as num).toDouble();
    final newBal = (bal - amount).clamp(0, 1e12).toDouble();
    loans[idx]['balance'] = newBal;
    int newScore = (meta['creditScore'] ?? Balance.creditScoreStart) as int;
    // If fully repaid, bump score and remove loan
    if (newBal <= 0.0) {
      final principal = (loans[idx]['principal'] as num).toInt();
      loans.removeAt(idx);
      newScore = (newScore + Balance.creditScorePayoffBump).clamp(Balance.creditScoreMin, Balance.creditScoreMax);
      // small positive brand rep for financial responsibility
      final rep = (meta['brandRep'] ?? 50) as int;
      state = {
        ...state,
        'cash': cash - amount,
        'meta': {
          ...meta,
          'loans': loans,
          'creditScore': newScore,
          'brandRep': (rep + (principal >= 1000 ? 2 : 1)).clamp(0, 100),
        }
      };
    } else {
      state = {
        ...state,
        'cash': cash - amount,
        'meta': {
          ...meta,
          'loans': loans,
        }
      };
    }
    SaveService.autosave(state);
  }

  // Daily interest accrual on outstanding loans; called inside endDay
  Map<String, dynamic> _applyLoanInterest(int currentDay) {
    final loans = (meta['loans'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? <Map<String, dynamic>>[];
    double totalAccrued = 0.0;
    for (final l in loans) {
      final bal = (l['balance'] as num).toDouble();
      final rate = (l['dailyRate'] as num).toDouble();
      final interest = (bal * rate);
      l['balance'] = bal + interest;
      totalAccrued += interest;
    }
    return {
      'loans': loans,
      'accrued': totalAccrued.round(),
    };
  }

  void addFactionTaxToday(int amount) {
    if (amount <= 0) return;
    final taxToday = (meta['factionTaxToday'] ?? 0) as int;
    state = {
      ...state,
      'meta': {
        ...meta,
        'factionTaxToday': taxToday + amount,
      }
    };
    SaveService.autosave(state);
  }

  void bribePolice() {
    if (cash < Balance.policeBribeCost) return;
    state = {
      ...state,
      'cash': cash - Balance.policeBribeCost,
      'meta': {
        ...meta,
        'policeBribedToday': true,
      }
    };
    SaveService.autosave(state);
  }

  void setBankCompound(bool v) {
    state = {
      ...state,
      'meta': {
        ...meta,
        'bankCompound': v,
      }
    };
    SaveService.autosave(state);
  }

  void payBail(int bail) {
    if (bail <= 0 || cash < bail) return;
    state = {
      ...state,
      'cash': cash - bail,
      'heat': 0.0,
    };
    SaveService.autosave(state);
  }

  void takePleaDeal() {
    state = {
      ...state,
      'cash': (cash * 0.8).round(),
      'heat': 0.0,
    };
    SaveService.autosave(state);
  }

  // LEGAL: add/update cases and actions
  void addLegalCase(Map<String, dynamic> caseJson) {
    final list = (meta['legalCases'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? <Map<String, dynamic>>[];
    list.add(caseJson);
    state = {
      ...state,
      'meta': {
        ...meta,
        'legalCases': list,
      }
    };
    SaveService.autosave(state);
  }

  void setLawyer({required int retainer, int? quality}) {
    state = {
      ...state,
      'meta': {
        ...meta,
        'lawyerRetainer': retainer.clamp(0, 1000000),
        if (quality != null) 'lawyerQuality': quality.clamp(0, 3),
      }
    };
    SaveService.autosave(state);
  }

  // Increase lawyer retainer by amount, charging cash
  void retainLawyer(int amount) {
    final add = amount.clamp(0, 1 << 30);
    if (add <= 0 || cash < add) return;
    final cur = (meta['lawyerRetainer'] ?? 0) as int;
    state = {
      ...state,
      'cash': cash - add,
      'meta': {
        ...meta,
        'lawyerRetainer': cur + add,
      }
    };
    SaveService.autosave(state);
  }

  // Improve lawyer quality by 1 (up to 3) for a flat fee
  void improveLawyerQuality({int cost = 500}) {
    if (cash < cost) return;
    final q = ((meta['lawyerQuality'] ?? 0) as int).clamp(0, 3);
    if (q >= 3) return;
    state = {
      ...state,
      'cash': cash - cost,
      'meta': {
        ...meta,
        'lawyerQuality': (q + 1).clamp(0, 3),
      }
    };
    SaveService.autosave(state);
  }

  void payBailForCase(String caseId) {
    final list = (meta['legalCases'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? <Map<String, dynamic>>[];
    final idx = list.indexWhere((e) => e['id'] == caseId);
    if (idx < 0) return;
    final bail = (list[idx]['bail'] ?? 0) as int;
    if (bail <= 0 || cash < bail) return;
    list[idx]['status'] = 'bailed';
    state = {
      ...state,
      'cash': cash - bail,
      'meta': {
        ...meta,
        'legalCases': list,
      }
    };
    SaveService.autosave(state);
  }

  int _capacity() {
    final up = upgrades;
    int base = 50 + up.safehouse * 50; // base + per level
    // district storage bonus if available
    try {
      // Access provider container cautiously only where available; otherwise ignore
      // This getter may be used from UI with a ref, so we keep base logic simple.
    } catch (_) {}
    final metaMap = meta;
    final districtBonus = (metaMap['districtStorageBonus'] ?? 0) as int;
    return base + districtBonus;
  }

  // Public accessor for stash capacity
  int capacity() => _capacity();

  void buy(String drugId, int qty, int price) {
    final totalHeld = inventory.drugs.values.fold<int>(0, (a, b) => a + b);
    if (cash >= price && totalHeld + qty <= _capacity()) {
      state = {
        ...state,
        'cash': cash - price,
        'inventory': Inventory(drugs: {
          ...inventory.drugs,
          drugId: inventory.drugs[drugId]! + qty,
        }).toJson(),
      };
      SaveService.autosave(state);
    }
  }

  void sell(String drugId, int qty, int price, {String? customerType}) {
    if (inventory.drugs[drugId]! >= qty) {
      final salesToday = (meta['salesToday'] ?? 0) as int;
      // update loyalty for customer type if provided
      Map<String, dynamic> metaMap = meta;
      final loyaltyRaw = metaMap['loyalty'];
      final loyalty = loyaltyRaw is Map ? Map<String, dynamic>.from(loyaltyRaw) : <String, dynamic>{};
      // track units sold today, and per-drug totals for chains
  final unitsSoldToday = (meta['unitsSoldToday'] ?? 0) as int;
      final soldRaw = meta['soldTodayByDrug'];
      final soldByDrug = soldRaw is Map ? Map<String, dynamic>.from(soldRaw) : <String, dynamic>{};
      final prevDrug = (soldByDrug[drugId] ?? 0) as int;
  // track per-district per-drug too for routing constraints
  final soldByDDRaw = meta['soldByDistrictDrugUnits'];
  final soldByDD = soldByDDRaw is Map ? Map<String, dynamic>.from(soldByDDRaw) : <String, dynamic>{};
  final earnedToday = (meta['cashEarnedToday'] ?? 0) as int;
      if (customerType != null) {
        final v = ((loyalty[customerType] ?? 1.0) as num).toDouble();
        // nudge towards 2.0 cap
        final nv = (v + 0.05).clamp(0.5, 2.0);
        loyalty[customerType] = nv;
      }
  // pattern tracking key
  final districtIdx = (meta['currentDistrict'] ?? 0) as int;
  final districtId = (meta['currentDistrictId'] ?? '') as String;
      final dKey = 'd${districtIdx}_$drugId';
      final patRaw = meta['patternByDistrictDrug'];
      final pattern = patRaw is Map ? Map<String, dynamic>.from(patRaw) : <String, dynamic>{};
      final prevPattern = (pattern[dKey] ?? 0) as int;
      // evidence grows with price velocity (superlinear) and patterns
      final pricePerUnit = qty == 0 ? 0.0 : (price / qty);
      final velocity = pricePerUnit * qty; // simplistic daily revenue chunk
  // Burner phones reduce evidence growth
  final burnerLvl = upgrades.burner;
  final evGrowBase = (velocity / 500.0);
  final evGrow = evGrowBase * (1.0 - 0.12 * burnerLvl).clamp(0.6, 1.0);
  final evNew = ((meta['evidence'] ?? 0.0) as num).toDouble() + evGrow + (prevPattern > 1 ? 0.1 * prevPattern : 0.0);
      state = {
        ...state,
        'cash': cash + price,
        'inventory': Inventory(drugs: {
          ...inventory.drugs,
          drugId: inventory.drugs[drugId]! - qty,
        }).toJson(),
        'meta': {
          ...meta,
          'salesToday': salesToday + 1,
          'unitsSoldToday': unitsSoldToday + qty,
          'soldTodayByDrug': {
            ...soldByDrug,
            drugId: prevDrug + qty,
          },
          'soldByDistrictDrugUnits': {
            ...soldByDD,
            dKey: ((soldByDD[dKey] ?? 0) as int) + qty,
            if (districtId.isNotEmpty) 'did_${districtId}_$drugId': ((soldByDD['did_${districtId}_$drugId'] ?? 0) as int) + qty,
          },
          'cashEarnedToday': earnedToday + price,
          'patternByDistrictDrug': {
            ...pattern,
            dKey: prevPattern + 1,
          },
          'evidence': evNew,
          if (customerType != null) 'loyalty': loyalty,
        }
      };
      SaveService.autosave(state);
    }
  }

  void travel(int cost, double heatInc, {int? toDistrictIndex, String? toDistrictId, double? heatDecayBonus, int? storageBonus}) {
    state = {
      ...state,
      'cash': cash - cost,
      'heat': (heat + heatInc).clamp(0, 1.0),
      'meta': {
        ...meta,
        if (toDistrictIndex != null) 'currentDistrict': toDistrictIndex,
        if (toDistrictId != null) 'currentDistrictId': toDistrictId,
        if (heatDecayBonus != null) 'districtHeatDecayBonus': heatDecayBonus,
        if (storageBonus != null) 'districtStorageBonus': storageBonus,
      }
    };
    SaveService.autosave(state);
  }

  void launder(int amount) {
    if (amount <= cash && amount <= Balance.launderingCap) {
      state = {
        ...state,
        'cash': cash - amount,
        'meta': {
          ...meta,
          'laundered': (meta['laundered'] ?? 0) + amount,
        },
      };
      SaveService.autosave(state);
    }
  }

  void endDay() {
    // Crew wages: enforce automatic deduction (provided by crew provider via meta)
    final int wages = ((meta['wagesDue'] ?? 0) as num).toInt();

    // Brand adjustments
    int rep = ((meta['brandRep'] ?? 50) as num).toInt();
    final int purity = ((meta['purityBoost'] ?? 0) as num).toInt();
    final bool adulterant = (meta['adulterantActive'] ?? false) == true;
    rep = (rep + purity - (adulterant ? 2 : 0)).clamp(0, 100);

    // Bank interest and maintenance
    int bankBal = bank;
    int interest = 0;
    if (bankBal > 0) {
      double rate;
      if (bankBal <= Balance.bankTier1Limit) rate = Balance.bankTier1Rate;
      else if (bankBal <= Balance.bankTier2Limit) rate = Balance.bankTier2Rate;
      else rate = Balance.bankTier3Rate;
      final earned = (bankBal * rate).round();
      interest = earned;
      if (bankCompound) {
        bankBal += earned;
      }
    }
    int maintenance = 0;
    if (bankBal > 0 && bankBal < Balance.bankLowBalanceThreshold) {
      maintenance = Balance.bankDailyMaintenanceFee;
      bankBal = ((bankBal - maintenance).clamp(0, bankBal)).toInt();
    }
    try {
      final up = upgrades;
      maintenance += up.vehicle * 3 + up.safehouse * 5 + up.scanner * 2 + up.burner * 2;
      final capacity = _capacity();
      if (capacity > 100) maintenance += ((capacity - 100) / 50).ceil();
    } catch (_) {}

    final double heatDecayBonus = ((meta['districtHeatDecayBonus'] ?? 0.0) as num).toDouble();

    // Initialize aggregates used below
    int cashDelta = 0;
    int auditFee = 0;
    int salesToday = ((meta['salesToday'] ?? 0) as num).toInt();
    int unitsSoldToday = ((meta['unitsSoldToday'] ?? 0) as num).toInt();
    final soldByDrugRaw = meta['soldTodayByDrug'];
    final Map<String, int> soldByDrug = {};
    if (soldByDrugRaw is Map) {
      soldByDrugRaw.forEach((k, v) => soldByDrug[k.toString()] = (v as num).toInt());
    }
    int slaPenalty = 0;
    int vipPenalty = 0;
    Map<String, int> missStreak = {};
    int chainReward = 0;
    Map<String, dynamic> chain = {};
    List<Map<String, dynamic>> nextDayEvents = [];

    // Supplier SLA penalty
    try {
      final contracts = (meta['contracts'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          const <Map<String, dynamic>>[];
      int totalMin = 0;
      // compute per-supplier meet/miss
      final trustRaw = meta['supplierTrustById'];
      final Map<String, double> trust = trustRaw is Map
          ? Map<String, double>.from(trustRaw.map((k, v) => MapEntry(k.toString(), ((v as num).toDouble()).clamp(0.0, 1.0))))
          : <String, double>{};
      final Map<String, bool> met = <String, bool>{};
      for (final c in contracts) {
        final until = (c['contractedUntilDay'] ?? 0) as int;
        final minDaily = (c['minDaily'] ?? 0) as int;
        final id = (c['id'] ?? '') as String;
        if (day <= until && minDaily > 0) {
          totalMin += minDaily;
          met[id] = unitsSoldToday >= minDaily;
        }
      }
      final unmet = (totalMin - unitsSoldToday).clamp(0, totalMin);
      slaPenalty = unmet > 0 ? (50 + 10 * unmet) : 0;
      // trust adjustment: small up if met, down if missed
      if (met.isNotEmpty) {
        met.forEach((id, ok) {
          final cur = (trust[id] ?? 0.5);
          final delta = ok ? 0.02 : -0.04;
          trust[id] = (cur + delta).clamp(0.0, 1.0);
        });
        meta['supplierTrustById'] = trust;
      }
    } catch (_) {}

    // VIP penalties with optional district restriction and streaks
    try {
      final vipList = (meta['vipContracts'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          const <Map<String, dynamic>>[];
      final missStreakRaw = meta['vipMissStreakByDrug'];
      missStreak = missStreakRaw is Map
          ? Map<String, int>.from(missStreakRaw.map((k, v) => MapEntry(k.toString(), (v as num).toInt())))
          : <String, int>{};
      final byDDRaw = meta['soldByDistrictDrugUnits'];
      final Map<String, int> byDD = {};
      if (byDDRaw is Map) {
        byDDRaw.forEach((k, v) => byDD[k.toString()] = (v as num).toInt());
      }
      for (final v in vipList) {
        final until = (v['contractedUntilDay'] ?? 0) as int;
        final minDaily = (v['minDaily'] ?? 0) as int;
        if (day <= until && minDaily > 0) {
          final drugId = (v['drugId'] ?? '') as String;
          int sold;
          final restrictId = (v['restrictDistrictId'] ?? '') as String;
          if (restrictId.isNotEmpty) {
            sold = (byDD['did_${restrictId}_$drugId'] ?? 0);
          } else {
            sold = (soldByDrug[drugId] ?? 0);
          }
          final miss = (minDaily - sold).clamp(0, minDaily);
          if (miss > 0) {
            final streak = (missStreak[drugId] ?? 0) + 1;
            missStreak[drugId] = streak;
            vipPenalty += (80 + 15 * miss + 25 * streak);
          } else {
            missStreak[drugId] = 0;
          }
        }
      }
    } catch (_) {}

    // Contract chain progression
    try {
      final chainRaw = meta['chain'];
      if (chainRaw is Map) chain = Map<String, dynamic>.from(chainRaw);
      if (chain.isNotEmpty && (chain['active'] ?? false) == true) {
        final int step = (chain['step'] ?? 0) as int;
        final List<dynamic> steps = (chain['steps'] as List<dynamic>? ?? const []);
        if (step < steps.length) {
          final req = Map<String, dynamic>.from(steps[step] as Map);
          final reqDrug = req['drugId'] as String;
          final reqQty = (req['qty'] ?? 0) as int;
          final sold = (soldByDrug[reqDrug] ?? 0);
          if (sold >= reqQty) {
            chainReward += (req['reward'] ?? 0) as int;
            final newStep = step + 1;
            chain['step'] = newStep;
            if (newStep >= steps.length) {
              chain['active'] = false;
              nextDayEvents.add({'day': day + 1, 'type': 'Chain', 'desc': 'Chain complete. Reward: \$${req['reward']}'});
            } else {
              final nextReq = Map<String, dynamic>.from(steps[newStep] as Map);
              nextDayEvents.add({'day': day + 1, 'type': 'Chain', 'desc': 'Chain step done (+\$${req['reward']}). Next: sell ${nextReq['qty']}x ${nextReq['drugId']}'});
            }
          }
        }
      }
    } catch (_) {}

    // Seed a rumor
    try {
      final rng = Rng((day + 1) * 99991);
      final weights = {
        'Festival': 0.25,
        'Drought': 0.2,
        'Gang War': 0.2,
        'Raid': 0.15,
        'Quiet': 0.2,
      };
      final pick = rng.pickWeighted(weights.keys.toList(), weights.values.toList());
      meta['rumorNext'] = {'type': pick, 'day': day + 1};
    } catch (_) {}

    // Global shortages chance
    List<Map<String, dynamic>> updatedShortages = (meta['globalShortages'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        <Map<String, dynamic>>[];
    try {
      final rng = Rng(day * 42407);
      if (rng.nextDoubleRange(0, 1) < 0.08) {
        final d = rng.pickWeighted(drugCatalog, drugCatalog.map((d) => d.rarity).toList());
        final until = day + 1 + rng.nextIntRange(2, 4);
        updatedShortages.add({'drugId': d.id, 'untilDay': until});
        nextDayEvents.add({'day': day + 1, 'type': 'Shortage', 'desc': 'Global shortage: ${d.name} scarce for a few days.'});
      }
    } catch (_) {}

    // Weekly mutation for next week
    Map<String, dynamic> nextMutation = Map<String, dynamic>.from(meta['mutationOfWeek'] as Map? ?? const {});
    try {
      if ((day + 1) % 7 == 1) {
        final muts = [
          {'type': 'ExpensiveWeek', 'desc': 'Distribution costs up this week.'},
          {'type': 'ScarceWeek', 'desc': 'Supply chains are tight this week.'},
          {'type': 'None', 'desc': 'No notable shifts this week.'},
        ];
        final rng = Rng((day + 1) * 17749);
        final mut = rng.pickWeighted(muts, [0.35, 0.25, 0.4]);
        nextMutation = Map<String, dynamic>.from(mut);
        if (mut['type'] != 'None') {
          nextDayEvents.add({'day': day + 1, 'type': 'Global', 'desc': mut['desc'] ?? 'Global change this week.'});
        }
      }
    } catch (_) {}

    // Objectives update and rewards
    final List<Map<String, dynamic>> objectives = (meta['objectives'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const <Map<String, dynamic>>[];
    final updatedObjectives = <Map<String, dynamic>>[];
    final int bankEnd = bankBal;
    for (final o in objectives) {
      bool done = o['done'] ?? false;
      if (!done) {
        switch (o['kind']) {
          case 'sell_any':
            done = salesToday >= (o['target'] ?? 1);
            break;
          case 'bank_ge':
            done = bankEnd >= (o['target'] ?? 0);
            break;
        }
        if (done) cashDelta += (o['reward'] ?? 0) as int;
      }
      updatedObjectives.add({
        ...o,
        'done': done,
      });
    }

    // Evidence decay and pattern attenuation
    double evidence = ((meta['evidence'] ?? 0.0) as num).toDouble();
    final laundered = ((meta['laundered'] ?? 0) as num).toInt();
    evidence = (evidence - laundered / 1000.0 - 0.15).clamp(0.0, 999.0);
    final patRaw = meta['patternByDistrictDrug'];
    final pattern = patRaw is Map ? Map<String, dynamic>.from(patRaw) : <String, dynamic>{};
    final nextPattern = <String, int>{};
    pattern.forEach((k, v) {
      final nv = ((v as num).toInt() - 1).clamp(0, 9999);
      if (nv > 0) nextPattern[k] = nv;
    });

    // Include crew conflict costs accrued earlier
    try {
      maintenance += ((meta['crewConflictToday'] ?? 0) as num).toInt();
    } catch (_) {}

    // Bank audit fee based on movement
    final bankDeltaToday = ((meta['bankDeltaToday'] ?? 0) as num).toInt();
    final absDelta = bankDeltaToday.abs();
    if (absDelta >= 1000) {
      auditFee = (absDelta * 0.005).round().clamp(5, 250);
    }

    // Perishable decay for certain products
    final inv = inventory;
    final decayRate = upgrades.safehouse > 0 ? 0.02 : 0.05;
    final newDrugs = Map<String, int>.from(inv.drugs);
    if (newDrugs.containsKey('weed')) {
      final cur = newDrugs['weed'] ?? 0;
      final dec = (cur * decayRate).floor();
      newDrugs['weed'] = (cur - dec).clamp(0, cur);
    }
    final newInv = Inventory(drugs: newDrugs).toJson();

    // Apply loan interest then autopay minimums
    final loanResult = _applyLoanInterest(day);
    List<Map<String, dynamic>> updatedLoans = (loanResult['loans'] as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final loanAccrued = (loanResult['accrued'] as int);
    int autoLoanPaid = 0;
    int totalMinDue = 0;
    final perLoanMin = <int>[];
    for (final l in updatedLoans) {
      final bal = (l['balance'] as num).toDouble();
      if (bal <= 0) {
        perLoanMin.add(0);
        continue;
      }
      final minByRate = (bal * Balance.loanMinPaymentRate).round();
      final minPay = minByRate < Balance.loanMinPaymentBase ? Balance.loanMinPaymentBase : minByRate;
      perLoanMin.add(minPay);
      totalMinDue += minPay;
    }
    int availableCash = cash;
    if (availableCash < totalMinDue) {
      final shortfall = totalMinDue - availableCash;
      int grossNeeded = shortfall;
      int fee(int gross) => (gross * Balance.bankWithdrawFeeRate).round().clamp(Balance.bankWithdrawMinFee, gross);
      while (grossNeeded - fee(grossNeeded) < shortfall && grossNeeded < shortfall + 100000) {
        grossNeeded += 1;
      }
      int willWithdraw = grossNeeded.clamp(0, bankBal);
      if (willWithdraw > 0) {
        final feeAmt = fee(willWithdraw);
        final net = (willWithdraw - feeAmt).clamp(0, willWithdraw);
        availableCash += net;
        bankBal -= willWithdraw;
        state = {
          ...state,
          'meta': {
            ...meta,
            'lastBankFee': feeAmt,
            'bankDeltaToday': (meta['bankDeltaToday'] ?? 0) - willWithdraw,
          }
        };
      }
    }
    for (int i = 0; i < updatedLoans.length; i++) {
      final l = updatedLoans[i];
      final bal = (l['balance'] as num).toDouble();
      int due = perLoanMin[i];
      if (bal <= 0 || due <= 0) continue;
      final pay = due.clamp(0, availableCash);
      if (pay > 0) {
        l['balance'] = (bal - pay).clamp(0, 1e12);
        autoLoanPaid += pay;
        availableCash -= pay;
      }
      if (availableCash <= 0) break;
    }

    // Commit next day state and reset daily counters
    // Insert influence decay and rivals contest prior to writing meta
    final inflRaw = meta['influenceByDistrict'];
    final Map<String, int> infl = inflRaw is Map
        ? Map<String, int>.from(inflRaw.map((k, v) => MapEntry(k.toString(), (v as num).toInt())))
        : <String, int>{};
    final String homeDid = (meta['homeDistrictId'] ?? '') as String;
    final nextInfl = <String, int>{};
    infl.forEach((did, val) {
      int nv = (val - 1).clamp(0, 100);
      if (homeDid.isNotEmpty && did == homeDid) nv = (nv + 1).clamp(0, 100);
      nextInfl[did] = nv;
    });
    // Protection applies for tonight's rival contest; then decremented for storage
    final protRaw = meta['protectionByDistrict'];
    final Map<String, int> protectionTonight = protRaw is Map
        ? Map<String, int>.from(protRaw.map((k, v) => MapEntry(k.toString(), (v as num).toInt())))
        : <String, int>{};
    try {
      final res = _runRivals(nextInfl, homeDid, day, protection: protectionTonight);
      final Map<String, int> d = Map<String, int>.from(res['delta'] as Map);
      d.forEach((did, dv) => nextInfl[did] = ((nextInfl[did] ?? 0) + dv).clamp(0, 100));
      final List<Map<String, dynamic>> evs = (res['events'] as List<dynamic>).map((e) => Map<String, dynamic>.from(e)).toList();
      if (evs.isNotEmpty) {
        nextDayEvents.addAll(evs);
      }
    } catch (_) {}
    // AI opponents take their turns: push influence, poach suppliers, increase police pressure
    try {
      final aiRes = _runAiOpponents(nextInfl, day, homeDid);
      final Map<String, int> d2 = Map<String, int>.from(aiRes['deltaInfl'] as Map);
      d2.forEach((did, dv) => nextInfl[did] = ((nextInfl[did] ?? 0) + dv).clamp(0, 100));
      final List<Map<String, dynamic>> aiev = (aiRes['events'] as List<dynamic>).map((e) => Map<String, dynamic>.from(e)).toList();
      if (aiev.isNotEmpty) nextDayEvents.addAll(aiev);
      // Supplier trust adjustments
      final trustAdjRaw = aiRes['supplierTrustDelta'];
      if (trustAdjRaw is Map) {
        final trustRaw = meta['supplierTrustById'];
        final Map<String, double> trust = trustRaw is Map
            ? Map<String, double>.from(trustRaw.map((k, v) => MapEntry(k.toString(), ((v as num).toDouble()).clamp(0.0, 1.0))))
            : <String, double>{};
        trustAdjRaw.forEach((sid, dv) {
          final key = sid.toString();
          final cur = (trust[key] ?? 0.5);
          final nd = ((dv as num).toDouble());
          trust[key] = (cur + nd).clamp(0.0, 1.0);
        });
        meta['supplierTrustById'] = trust;
      }
      // Police pressure updates (map did -> days)
      final pressAddsRaw = aiRes['policePressureAdds'];
      final ppRaw = meta['policePressureByDid'];
      final Map<String, int> pp = ppRaw is Map
          ? Map<String, int>.from(ppRaw.map((k, v) => MapEntry(k.toString(), (v as num).toInt())))
          : <String, int>{};
      if (pressAddsRaw is Map) {
        pressAddsRaw.forEach((did, days) {
          final key = did.toString();
          final add = (days as num).toInt();
          pp[key] = (pp[key] ?? 0) + add;
        });
      }
      // Decrement one day for storage into next state handled below along with protection
      // Store back into meta after decrement below
      meta['policePressureByDid'] = pp;
    } catch (_) {}
    // Decrement protection days for storage into next state
    final Map<String, int> protectionNext = {};
    protectionTonight.forEach((did, days) {
      if (days > 0) protectionNext[did] = (days - 1).clamp(0, 3650);
    });
    // Decrement police pressure days for storage into next state
    final ppTonightRaw = meta['policePressureByDid'];
    final Map<String, int> pressureNext = ppTonightRaw is Map
        ? Map<String, int>.from(ppTonightRaw.map((k, v) => MapEntry(k.toString(), ((v as num).toInt() - 1).clamp(0, 3650))))
        : <String, int>{};
    pressureNext.removeWhere((key, value) => value <= 0);
  // Decrement supplier shields days
  final shTonightRaw = meta['supplierShieldById'];
  final Map<String, int> shieldsNext = shTonightRaw is Map
    ? Map<String, int>.from(shTonightRaw.map((k, v) => MapEntry(k.toString(), ((v as num).toInt() - 1).clamp(0, 3650))))
    : <String, int>{};
  shieldsNext.removeWhere((key, value) => value <= 0);

    // Nightly finance instruments drift/premiums
    final int shellFund = ((meta['shellFund'] ?? 0) as num).toInt();
    final int cryptoFund = ((meta['cryptoFund'] ?? 0) as num).toInt();
    final bool insuranceEnabled = (meta['insuranceEnabled'] ?? false) == true;
    final int insurancePremium = ((meta['insurancePremium'] ?? 50) as num).toInt().clamp(0, 1000000);
    final rngFinance = Rng(day * 337 + 13);
    final int shellDrift = (shellFund * 0.002).round(); // +0.2%/day
    final double cryptoRate = rngFinance.nextDoubleRange(-0.02, 0.02); // -2% .. +2%
    final int cryptoPnl = (cryptoFund * cryptoRate).round();
    final int newShellFund = (shellFund + shellDrift).clamp(0, 1 << 31);
    final int newCryptoFund = (cryptoFund + cryptoPnl).clamp(0, 1 << 31);
    final int insuranceCost = insuranceEnabled ? insurancePremium : 0;
    // Resolve/advance legal cases for next day
    final casesRaw = meta['legalCases'];
    final List<Map<String, dynamic>> cases = casesRaw is List
        ? casesRaw.map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> nextCases = <Map<String, dynamic>>[];
    int legalFines = 0;
  final Map<String, int> crewJailAdds = <String, int>{};
  try {
      for (final c in cases) {
        String status = (c['status'] ?? 'open') as String;
        int days = (c['daysUntilHearing'] ?? 1) as int;
        if (status == 'resolved') { nextCases.add(c); continue; }
        if (status == 'open' || status == 'bailed') {
          days = (days - 1).clamp(0, 3650);
          if (days <= 0) {
            // hearing: compute conviction chance
            final severity = (c['severity'] ?? 1) as int;
            double p = 0.35 + 0.2 * (severity - 1);
            final ret = ((meta['lawyerRetainer'] ?? 0) as int);
            final qual = ((meta['lawyerQuality'] ?? 0) as int);
            if (ret > 0) p *= 0.8; // retainer reduces
            if (qual > 0) p *= (1 - 0.08 * qual);
            final r = Rng(day * 739 + severity).nextDoubleRange(0, 1);
            final convicted = r < p;
            if (convicted) {
              final fine = (c['fineOnConviction'] ?? 100) as int;
              final jailDays = (c['jailDaysOnConviction'] ?? 2) as int;
              legalFines += fine;
              // If crew case, mark crew jailed via event tomorrow
              if ((c['type'] ?? '') == 'crew') {
                final crewId = (c['crewId'] ?? '') as String;
                if (crewId.isNotEmpty) {
                  crewJailAdds[crewId] = (crewJailAdds[crewId] ?? 0) + jailDays;
                }
              }
              nextDayEvents.add({'day': day + 1, 'type': 'Court', 'desc': 'Court: conviction. Fine \$${fine}. ${(c['type']=='crew') ? 'Crew jailed '+(jailDays.toString())+'d.' : ''}'});
            } else {
              nextDayEvents.add({'day': day + 1, 'type': 'Court', 'desc': 'Court: case dismissed.'});
            }
            c['status'] = 'resolved';
            c['daysUntilHearing'] = 0;
            nextCases.add(c);
          } else {
            c['daysUntilHearing'] = days;
            nextCases.add(c);
          }
        }
      }
    } catch (_) {}

    state = {
      ...state,
      'day': day + 1,
      'heat': (heat * (1 - Balance.heatDecay - heatDecayBonus)).clamp(0, 1.0),
      'cash': cash - wages - maintenance - slaPenalty - vipPenalty - auditFee - loanAccrued - autoLoanPaid - insuranceCost - legalFines + cashDelta + chainReward + (upgrades.laundromat > 0 ? Balance.passiveIncome : 0) + (bankCompound ? 0 : interest),
      'inventory': newInv,
      'meta': {
        ...meta,
        'adulterantActive': false,
        'adulterantFlaggedToday': false,
        'brandRep': rep,
        'wagesDue': 0,
        'lastWagesPaid': wages,
        'bank': bankBal,
        'lastInterest': interest,
        'lastMaintenanceFee': maintenance,
        'lastVipPenalty': vipPenalty,
        'lastLoanAutoPaid': autoLoanPaid,
        'lastUnitsSold': unitsSoldToday,
        'lastCashDelta': -wages - maintenance - slaPenalty - vipPenalty - auditFee - autoLoanPaid - insuranceCost + cashDelta + chainReward + (upgrades.laundromat > 0 ? Balance.passiveIncome : 0) + (bankCompound ? 0 : interest),
        'salesToday': 0,
        'unitsSoldToday': 0,
        'soldTodayByDrug': <String, int>{},
        'soldByDistrictDrugUnits': <String, int>{},
        'patternByDistrictDrug': nextPattern,
        'evidence': evidence,
        'cashEarnedToday': 0,
        'factionTaxToday': 0,
        'lastFactionTax': (meta['factionTaxToday'] ?? 0) as int,
        'lastAuditFee': auditFee,
        'bankDeltaToday': 0,
        'crewConflictToday': 0,
        'crewBankCreditToday': 0,
        'lastCrewConflict': (meta['crewConflictToday'] ?? 0) as int,
        'lastCrewBankCredit': (meta['crewBankCreditToday'] ?? 0) as int,
  if ((meta['crewEarningsToday'] as List<dynamic>? ?? const []).isNotEmpty)
    'lastCrewEarnings': ((meta['crewEarningsToday'] as List<dynamic>)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList()),
  'crewEarningsToday': <Map<String, dynamic>>[],
        'vipMissStreakByDrug': missStreak,
        'bribeStreak': (meta['policeBribedToday'] ?? false) == true ? (((meta['bribeStreak'] ?? 0) as int) + 1) : 0,
        'policeBribedToday': false,
        'dayPart': (meta['dayPart'] ?? 'Day') == 'Day' ? 'Night' : 'Day',
        'objectives': updatedObjectives,
        'objectiveRewarded': cashDelta > 0,
        'lastSlaPenalty': slaPenalty,
        'globalShortages': updatedShortages,
        'mutationOfWeek': nextMutation,
        'loans': updatedLoans,
        'lastLoanInterest': loanAccrued,
        'influenceByDistrict': nextInfl,
        // Protection updated after nightly effect
        if (protectionNext.isNotEmpty) 'protectionByDistrict': protectionNext,
  // Police pressure persists for a few days
  if (pressureNext.isNotEmpty) 'policePressureByDid': pressureNext,
  // Supplier shields persist
  if (shieldsNext.isNotEmpty) 'supplierShieldById': shieldsNext,
        // Finance instruments
        'shellFund': newShellFund,
        'cryptoFund': newCryptoFund,
        'lastShellDrift': shellDrift,
        'lastCryptoPnl': cryptoPnl,
  'lastInsurancePremium': insuranceCost,
  if (legalFines > 0) 'lastLegalFines': legalFines,
  if (nextCases.isNotEmpty) 'legalCases': nextCases,
        if (crewJailAdds.isNotEmpty) 'crewJailAddById': crewJailAdds,
        if (chain.isNotEmpty) 'chain': chain,
        if (nextDayEvents.isNotEmpty)
          'eventsForDay': [
            ...((meta['eventsForDay'] as List<dynamic>? ?? const [])).map((e) => Map<String, dynamic>.from(e)),
            ...nextDayEvents,
          ],
      }
    };
    SaveService.autosave(state);

    // Game over check remains below
    // Game over if broke
    try {
      final now = state;
      final c = (now['cash'] as int);
      final b = ((now['meta']?['bank'] ?? 0) as int);
      if (c <= 0 && b <= 0) {
        state = {
          ...state,
          'meta': {
            ...state['meta'],
            'gameOver': true,
          }
        };
        SaveService.autosave(state);
      }
    } catch (_) {}
  }

  // Lightweight AI turn: returns influence deltas, events, supplier trust deltas, and police pressure adds
  Map<String, dynamic> _runAiOpponents(Map<String, int> infl, int day, String homeDid) {
    final rng = Rng(day * 881 + 31);
    final aiListRaw = meta['aiOpponents'];
    final List<Map<String, dynamic>> aiList = aiListRaw is List
        ? aiListRaw.map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
  final difficulty = ((meta['aiDifficulty'] ?? 'normal') as String);
  // Scaling knobs
  final inflLossBase = difficulty == 'easy' ? 1 : (difficulty == 'hard' ? 2 : 1);
  final trustHit = difficulty == 'easy' ? -0.03 : (difficulty == 'hard' ? -0.07 : -0.05);
  final pressDays = difficulty == 'easy' ? 1 : (difficulty == 'hard' ? 3 : 2);
    final deltaInfl = <String, int>{};
    final events = <Map<String, dynamic>>[];
    final supplierTrustDelta = <String, double>{};
    final policePressureAdds = <String, int>{};
    if (aiList.isEmpty) return {
      'deltaInfl': deltaInfl,
      'events': events,
      'supplierTrustDelta': supplierTrustDelta,
      'policePressureAdds': policePressureAdds,
    };
    // Pick 1-2 actions per AI depending on budget
    for (final ai in aiList) {
      int budget = ((ai['budget'] ?? 300) as num).toInt();
      final personality = (ai['personality'] ?? 'aggressive') as String;
      int actions;
      if (difficulty == 'easy') actions = 1;
      else if (difficulty == 'hard') actions = 2;
      else actions = budget >= 600 ? 2 : 1;
      for (int i = 0; i < actions; i++) {
        // Choose action by personality
        final roll = rng.nextDoubleRange(0, 1);
        String action;
        if (personality == 'aggressive') {
          action = roll < 0.6 ? 'push_influence' : (roll < 0.8 ? 'police_tip' : 'poach_supplier');
        } else if (personality == 'economic') {
          action = roll < 0.5 ? 'poach_supplier' : (roll < 0.8 ? 'push_influence' : 'police_tip');
        } else { // legalist
          action = roll < 0.6 ? 'police_tip' : (roll < 0.85 ? 'push_influence' : 'poach_supplier');
        }
        switch (action) {
          case 'push_influence':
            {
              // Strategic: prefer top-influence districts (non-home) to dislodge you
              final entries = infl.entries.where((e) => e.value > 0 && e.key != homeDid).toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              List<String> candidates = entries.take(3).map((e) => e.key).toList();
              if (candidates.isEmpty) candidates = infl.keys.toList();
              if (candidates.isEmpty) break;
              final did = candidates[rng.nextIntRange(0, candidates.length - 1)];
              int loss = inflLossBase + rng.nextIntRange(0, 2);
              deltaInfl[did] = (deltaInfl[did] ?? 0) - loss;
              events.add({'type': 'AI', 'districtId': did, 'desc': '${ai['name'] ?? 'Rivals'} are leaning on your crews.'});
              budget -= 100;
              break;
            }
          case 'poach_supplier':
            {
              // Random supplier id key affected; assume existing trust map keys
              final trustRaw = meta['supplierTrustById'];
              final keys = trustRaw is Map ? trustRaw.keys.map((e) => e.toString()).toList() : <String>[];
              if (keys.isNotEmpty) {
                final sid = keys[rng.nextIntRange(0, keys.length - 1)];
                // Check for shields
                final shRaw = meta['supplierShieldById'];
                final shields = shRaw is Map ? Map<String, int>.from(shRaw.map((k, v) => MapEntry(k.toString(), (v as num).toInt()))) : <String, int>{};
                if ((shields[sid] ?? 0) > 0) {
                  events.add({'type': 'AI', 'districtId': homeDid, 'desc': 'Your supplier shield blocked a poach.'});
                } else {
                  supplierTrustDelta[sid] = (supplierTrustDelta[sid] ?? 0.0) + trustHit;
                  events.add({'type': 'AI', 'districtId': homeDid, 'desc': '${ai['name'] ?? 'Rivals'} poached a supplier. Trust fell.'});
                }
                budget -= 120;
              }
              break;
            }
          case 'police_tip':
            {
              // Increase police pressure: prefer high influence districts to hurt operations
              final entries = infl.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              if (entries.isNotEmpty) {
                final top = entries.take(3).map((e) => e.key).toList();
                final did = top[rng.nextIntRange(0, top.length - 1)];
                policePressureAdds[did] = (policePressureAdds[did] ?? 0) + pressDays;
                events.add({'type': 'AI', 'districtId': did, 'desc': 'Anonymous tip stirred up cops in the area.'});
                budget -= 80;
              }
              break;
            }
        }
        if (budget <= 0) break;
      }
      ai['budget'] = (budget + rng.nextIntRange(40, 120)).clamp(0, 1000000);
    }
    // Persist updated AI budgets
    state = {
      ...state,
      'meta': {
        ...meta,
        'aiOpponents': aiList,
      }
    };
    SaveService.autosave(state);
    return {
      'deltaInfl': deltaInfl,
      'events': events,
      'supplierTrustDelta': supplierTrustDelta,
      'policePressureAdds': policePressureAdds,
    };
  }

  // Set AI difficulty: easy | normal | hard
  void setAiDifficulty(String difficulty) {
    final d = ['easy', 'normal', 'hard'].contains(difficulty) ? difficulty : 'normal';
    state = {
      ...state,
      'meta': {
        ...meta,
        'aiDifficulty': d,
      }
    };
    SaveService.autosave(state);
  }

  // Spend cash to reduce police pressure in a district by daysRemove (min 1)
  void coolDistrictPolice(String districtId, {int daysRemove = 1, int costPerDay = 40}) {
    if (districtId.isEmpty) return;
    final ppRaw = meta['policePressureByDid'];
    final Map<String, int> pp = ppRaw is Map
        ? Map<String, int>.from(ppRaw.map((k, v) => MapEntry(k.toString(), (v as num).toInt())))
        : <String, int>{};
    final cur = (pp[districtId] ?? 0);
    if (cur <= 0) return;
    final remove = daysRemove.clamp(1, cur);
    final cost = remove * costPerDay;
    if (cash < cost) return;
    pp[districtId] = (cur - remove).clamp(0, 3650);
    if (pp[districtId] == 0) pp.remove(districtId);
    state = {
      ...state,
      'cash': cash - cost,
      'meta': {
        ...meta,
        'policePressureByDid': pp,
      }
    };
    SaveService.autosave(state);
  }

  // Apply a supplier shield to block poach attempts for a few days
  void secureSupplier(String supplierId, {int days = 3, int cost = 120}) {
    if (supplierId.isEmpty) return;
    if (cash < cost) return;
    final shRaw = meta['supplierShieldById'];
    final Map<String, int> shields = shRaw is Map
        ? Map<String, int>.from(shRaw.map((k, v) => MapEntry(k.toString(), (v as num).toInt())))
        : <String, int>{};
    shields[supplierId] = (shields[supplierId] ?? 0) + days.clamp(1, 30);
    state = {
      ...state,
      'cash': cash - cost,
      'meta': {
        ...meta,
        'supplierShieldById': shields,
      }
    };
    SaveService.autosave(state);
  }

  // Consume crew jail additions and clear them from meta; used by crew provider on day start
  Map<String, int> consumeCrewJailAdds() {
    final raw = meta['crewJailAddById'];
    final Map<String, int> adds = raw is Map
        ? Map<String, int>.from(raw.map((k, v) => MapEntry(k.toString(), (v as num).toInt())))
        : <String, int>{};
    if (adds.isEmpty) return adds;
    state = {
      ...state,
      'meta': {
        ...meta,
        'crewJailAddById': <String, int>{},
      }
    };
    SaveService.autosave(state);
    return adds;
  }

  void prestigeReset() {
    final p = ((meta['prestige'] ?? 0) as int) + 1;
    final perkPoints = ((meta['perkPoints'] ?? 0) as int) + 1;
    // reset to initial run but carry prestige/perkPoints forward
    final fresh = _initialState();
    final freshMeta = fresh['meta'] as Map<String, dynamic>;
    freshMeta['prestige'] = p;
    freshMeta['perkPoints'] = perkPoints;
    state = {
      ...fresh,
      'meta': freshMeta,
    };
    SaveService.autosave(state);
  }

  // Change automation settings
  void setAutomation(Map<String, dynamic> auto) {
    final metaMap = meta;
    state = {
      ...state,
      'meta': {
        ...metaMap,
        'auto': auto,
      }
    };
    SaveService.autosave(state);
  }

  // Crew autopilot settings
  void setCrewAutopilot(Map<String, dynamic> auto) {
    final metaMap = meta;
    state = {
      ...state,
      'meta': {
        ...metaMap,
        'crewAuto': auto,
      }
    };
    SaveService.autosave(state);
  }

  // Lightweight automation runner that uses provided price list
  void runAutomationWithPrices(List<Map<String, dynamic>> prices) {
    try {
      final metaMap = meta;
      final autoRaw = metaMap['auto'];
      final auto = autoRaw is Map ? Map<String, dynamic>.from(autoRaw) : const <String, dynamic>{};
      final bool enabled = (auto['enabled'] ?? false) as bool;
      if (!enabled) return;
      // Deposit excess
      final int depositAbove = ((auto['depositAbove'] ?? 0) as num).toInt();
      if (depositAbove > 0 && cash > depositAbove) {
        final amt = cash - depositAbove;
        if (amt > 0) depositBank(amt);
      }
      // Auto buy to reach min units
      final int minUnits = ((auto['buyMinUnits'] ?? 0) as num).toInt();
      if (minUnits > 0) {
        final cap = _capacity();
        int held = inventory.drugs.values.fold<int>(0, (a, b) => a + b);
        if (held < minUnits && held < cap) {
          final int maxSpendPct = ((auto['buyMaxSpendPct'] ?? 40) as num).toInt().clamp(0, 100);
          final int startCash = cash;
          final int spendCap = ((startCash * maxSpendPct) / 100.0).floor();
          int spent = 0;
          final sorted = [...prices];
          sorted.sort((a, b) => (a['price'] as int).compareTo(b['price'] as int));
          int i = 0;
          while (held < minUnits && held < cap && i < sorted.length) {
            final d = sorted[i]['drug'];
            final int p = sorted[i]['price'] as int;
            if (p <= 0) { i++; continue; }
            if (cash <= 0 || spent + p > spendCap) break;
            buy(d.id as String, 1, p);
            spent += p;
            held += 1;
          }
        }
      }
    } catch (_) {}
  }

  // Adjust influence by district ids
  void adjustInfluence(Map<String, int> deltaByDid) {
    final inflRaw = meta['influenceByDistrict'];
    final Map<String, int> infl = inflRaw is Map
        ? Map<String, int>.from(inflRaw.map((k, v) => MapEntry(k.toString(), (v as num).toInt())))
        : <String, int>{};
    deltaByDid.forEach((did, delta) {
      infl[did] = ((infl[did] ?? 0) + delta).clamp(0, 100);
    });
    state = {
      ...state,
      'meta': {
        ...meta,
        'influenceByDistrict': infl,
      }
    };
    SaveService.autosave(state);
  }

  void queueNextDayEvents(List<Map<String, dynamic>> events) {
    if (events.isEmpty) return;
    final dayNow = (state['day'] ?? 1) as int;
    final next = events
        .map((e) => {
              'day': dayNow + 1,
              'type': e['type'] ?? 'News',
              'desc': e['desc'] ?? '',
              'districtId': e['districtId'] ?? '',
              if (e['drugId'] != null) 'drugId': e['drugId'],
            })
        .toList();
    final metaMap = meta;
    state = {
      ...state,
      'meta': {
        ...metaMap,
        'eventsForDay': [
          ...((metaMap['eventsForDay'] as List<dynamic>? ?? const [])).map((e) => Map<String, dynamic>.from(e)),
          ...next,
        ],
      }
    };
    SaveService.autosave(state);
  }

  Map<String, dynamic> _runRivals(Map<String, int> infl, String homeDid, int day, {Map<String, int>? protection}) {
    final rng = Rng(day * 9901 + 7);
    final delta = <String, int>{};
    final events = <Map<String, dynamic>>[];
    final prot = protection ?? const <String, int>{};
    infl.forEach((did, val) {
      if (did == homeDid) return; // avoid direct core push for now
      double p = 0.35;
      int protDays = prot[did] ?? 0;
      if (protDays > 0) {
        p *= 0.2; // 80% less likely when protected
      }
      if (val > 0 && rng.nextDoubleRange(0, 1) < p) {
        int loss = rng.nextIntRange(1, 4);
        if (protDays > 0) loss = (loss - 1).clamp(0, loss);
        if (loss <= 0) return; // fully negated by protection
        delta[did] = -loss;
        if (val - loss <= 15) {
          events.add({'type': 'Rival', 'districtId': did, 'desc': 'Rivals are muscling in on one of your neighborhoods.'});
        }
      }
    });
    return {'delta': delta, 'events': events};
  }

  // Increase inventory for a specific drug and adjust cash for crafting flows
  void craftMeth(int spendDollars, int unitsPlanned) {
    final spend = spendDollars.clamp(0, 1 << 30);
    int units = unitsPlanned.clamp(0, 1 << 30);
    if (spend <= 0 || units <= 0) return;
    if (cash <= 0) return;
    final held = inventory.drugs.values.fold<int>(0, (a, b) => a + b);
    final cap = _capacity();
    final room = (cap - held).clamp(0, cap);
    if (room <= 0) return;
    final allowedUnits = units.clamp(0, room);
    // scale spend proportionally if we can't fit all planned units
    final adjustedSpend = ((spend.toDouble() * (allowedUnits / units))).round();
    state = {
      ...state,
      'cash': (cash - adjustedSpend).clamp(-1 << 31, 1 << 31),
      'inventory': Inventory(drugs: {
        ...inventory.drugs,
        'meth': (inventory.drugs['meth'] ?? 0) + allowedUnits,
      }).toJson(),
      'meta': {
        ...meta,
        'craftedSpendToday': ((meta['craftedSpendToday'] ?? 0) as int) + adjustedSpend,
        'craftedUnitsToday': ((meta['craftedUnitsToday'] ?? 0) as int) + allowedUnits,
      }
    };
    SaveService.autosave(state);
  }

  // Finance instruments controls
  void shellDeposit(int amount) {
    final n = amount.clamp(0, cash);
    if (n <= 0) return;
    state = {
      ...state,
      'cash': cash - n,
      'meta': {
        ...meta,
        'shellFund': ((meta['shellFund'] ?? 0) as int) + n,
      }
    };
    SaveService.autosave(state);
  }

  void shellWithdraw(int amount) {
    final cur = ((meta['shellFund'] ?? 0) as int);
    final n = amount.clamp(0, cur);
    if (n <= 0) return;
    state = {
      ...state,
      'cash': cash + n,
      'meta': {
        ...meta,
        'shellFund': cur - n,
      }
    };
    SaveService.autosave(state);
  }

  void cryptoDeposit(int amount) {
    final n = amount.clamp(0, cash);
    if (n <= 0) return;
    state = {
      ...state,
      'cash': cash - n,
      'meta': {
        ...meta,
        'cryptoFund': ((meta['cryptoFund'] ?? 0) as int) + n,
      }
    };
    SaveService.autosave(state);
  }

  void cryptoWithdraw(int amount) {
    final cur = ((meta['cryptoFund'] ?? 0) as int);
    final n = amount.clamp(0, cur);
    if (n <= 0) return;
    state = {
      ...state,
      'cash': cash + n,
      'meta': {
        ...meta,
        'cryptoFund': cur - n,
      }
    };
    SaveService.autosave(state);
  }

  void setInsurance(bool enabled, {int? premium}) {
    state = {
      ...state,
      'meta': {
        ...meta,
        'insuranceEnabled': enabled,
        if (premium != null) 'insurancePremium': premium.clamp(0, 1000000),
      }
    };
    SaveService.autosave(state);
  }

  // Write protection days by district safely
  void setProtectionByDistrict(Map<String, int> protection) {
    state = {
      ...state,
      'meta': {
        ...meta,
        'protectionByDistrict': protection,
      }
    };
    SaveService.autosave(state);
  }

  // Buy protection for a district for a number of days; costs costPerDay per day.
  void buyProtection(String districtId, int days, {int costPerDay = 50}) {
    if (districtId.isEmpty || days <= 0) return;
    final int cost = (days * costPerDay).clamp(0, 1 << 31);
    if (cash < cost) return;
    final protRaw = meta['protectionByDistrict'];
    final Map<String, int> prot = protRaw is Map
        ? Map<String, int>.from(protRaw.map((k, v) => MapEntry(k.toString(), (v as num).toInt())))
        : <String, int>{};
    prot[districtId] = (prot[districtId] ?? 0) + days;
    state = {
      ...state,
      'cash': cash - cost,
      'meta': {
        ...meta,
        'protectionByDistrict': prot,
      }
    };
    SaveService.autosave(state);
  }
}

final gameStateProvider = StateNotifierProvider<GameState, Map<String, dynamic>>((ref) => GameState());
