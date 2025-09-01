import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/types.dart';
import 'game_state.dart';

class UpgradeProvider extends StateNotifier<Upgrades> {
  final Ref _ref;
  UpgradeProvider(this._ref, Upgrades initial) : super(initial);

  void purchase(String upgrade) {
    // Define simple costs per level
  int costFor(String key, int nextLevel) {
      switch (key) {
        case 'vehicle':
      return 150 + 120 * nextLevel;
        case 'safehouse':
      return 200 + 160 * nextLevel;
        case 'burner':
      return 80 + 90 * nextLevel;
        case 'scanner':
      return 120 + 100 * nextLevel;
        case 'laundromat':
      return 900;
        default:
          return 200;
      }
    }

    Upgrades next = state;
    switch (upgrade) {
      case 'vehicle':
        if (state.vehicle < 4) next = Upgrades(vehicle: state.vehicle + 1, safehouse: state.safehouse, burner: state.burner, scanner: state.scanner, laundromat: state.laundromat);
        break;
      case 'safehouse':
        if (state.safehouse < 4) next = Upgrades(vehicle: state.vehicle, safehouse: state.safehouse + 1, burner: state.burner, scanner: state.scanner, laundromat: state.laundromat);
        break;
      case 'burner':
        if (state.burner < 4) next = Upgrades(vehicle: state.vehicle, safehouse: state.safehouse, burner: state.burner + 1, scanner: state.scanner, laundromat: state.laundromat);
        break;
      case 'scanner':
        if (state.scanner < 4) next = Upgrades(vehicle: state.vehicle, safehouse: state.safehouse, burner: state.burner, scanner: state.scanner + 1, laundromat: state.laundromat);
        break;
      case 'laundromat':
        if (state.laundromat < 1) next = Upgrades(vehicle: state.vehicle, safehouse: state.safehouse, burner: state.burner, scanner: state.scanner, laundromat: 1);
        break;
    }
    if (next == state) return; // no change
    final nextLevel = {
      'vehicle': next.vehicle,
      'safehouse': next.safehouse,
      'burner': next.burner,
      'scanner': next.scanner,
      'laundromat': next.laundromat,
    }[upgrade]!;
    final cost = costFor(upgrade, nextLevel);
    // Attempt to pay + persist via GameState
    final gs = _ref.read(gameStateProvider);
    if ((gs['cash'] as int) >= cost) {
      _ref.read(gameStateProvider.notifier).applyUpgrade(next, cost);
      state = next;
    }
  }

  // Public helpers for UI
  int maxLevel(String key) {
    switch (key) {
      case 'laundromat':
        return 1;
      default:
        return 4;
    }
  }

  int levelFor(String key) {
    switch (key) {
      case 'vehicle':
        return state.vehicle;
      case 'safehouse':
        return state.safehouse;
      case 'burner':
        return state.burner;
      case 'scanner':
        return state.scanner;
      case 'laundromat':
        return state.laundromat;
      default:
        return 0;
    }
  }

  int? nextCost(String key) {
    final cur = levelFor(key);
    final max = maxLevel(key);
    if (cur >= max) return null;
    final nextLevel = cur + 1;
    int calc(String k, int nl) {
      switch (k) {
        case 'vehicle':
          return 150 + 120 * nl;
        case 'safehouse':
          return 200 + 160 * nl;
        case 'burner':
          return 80 + 90 * nl;
        case 'scanner':
          return 120 + 100 * nl;
        case 'laundromat':
          return 900;
        default:
          return 200;
      }
    }
    return calc(key, nextLevel);
  }
}

final upgradeProvider = StateNotifierProvider<UpgradeProvider, Upgrades>((ref) {
  final raw = ref.watch(gameStateProvider.select((s) => s['upgrades']));
  final upMap = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  final up = Upgrades.fromJson(upMap);
  return UpgradeProvider(ref, up);
});
