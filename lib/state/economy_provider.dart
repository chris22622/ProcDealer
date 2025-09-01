import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/rng.dart';
import 'game_state.dart';
import 'event_provider.dart';

class EconomyDay {
  final String weather; // Sunny, Rainy, Cold
  final bool payday; // weekly payday
  final bool festival; // from events
  const EconomyDay({required this.weather, required this.payday, required this.festival});

  double priceMod() {
    double m = 1.0;
    if (payday) m *= 1.1;
    if (festival) m *= 1.1;
    switch (weather) {
      case 'Cold':
        m *= 1.05;
        break;
      case 'Rainy':
        m *= 0.98;
        break;
      default:
        break;
    }
    return m;
  }

  double riskMod() {
    double m = 1.0;
    if (festival) m *= 1.1; // crowds and police presence
    if (weather == 'Rainy') m *= 0.95; // fewer patrols seen
    return m;
  }
}

final economyProvider = Provider<EconomyDay>((ref) {
  final day = ref.watch(gameStateProvider.select((s) => s['day'] as int));
  final rng = Rng(day * 4243);
  final events = ref.watch(eventProvider);
  final festival = events.any((e) => e.type == 'Festival');
  final weather = rng.pickWeighted(['Sunny', 'Rainy', 'Cold'], [0.5, 0.3, 0.2]);
  final payday = day % 7 == 0;
  return EconomyDay(weather: weather, payday: payday, festival: festival);
});
