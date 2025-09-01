import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/rng.dart';
import '../core/types.dart';
import 'game_state.dart';
import 'city_provider.dart';
import 'crew_provider.dart';
import '../data/drug_catalog.dart';

final eventProvider = Provider<List<Event>>((ref) {
  final day = ref.watch(gameStateProvider.select((s) => s['day'] as int));
  final city = ref.watch(cityProvider);
  final rng = Rng(day * 99991);
  final events = <Event>[];
  // Include any meta-authored events for today (e.g., chains)
  final metaRaw = ref.watch(gameStateProvider.select((s) => s['meta']));
  final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
  final extra = (meta['eventsForDay'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? const <Map<String, dynamic>>[];
  for (final m in extra) {
    if ((m['day'] ?? -1) == day) {
      events.add(Event(type: m['type'] ?? 'News', districtId: '', desc: m['desc'] ?? ''));
    }
  }
  // Do not seed chains here to avoid state writes during provider build.
  // Beat director: bias events based on a simple cycle
  final beat = day % 7; // 0..6
  List<String> eventTypes = ['Festival', 'Raid', 'Drought', 'Gang War'];
  List<double> baseW = [0.3, 0.2, 0.2, 0.3];
  if (beat == 2 || beat == 3) {
    // squeeze
    baseW = [0.2, 0.3, 0.25, 0.25];
  } else if (beat == 4) {
    // crackdown
    baseW = [0.15, 0.4, 0.2, 0.25];
  } else if (beat == 5) {
    // respite
    baseW = [0.4, 0.15, 0.2, 0.25];
  }
  final n = rng.nextIntRange(0, 2);
  for (int i = 0; i < n; i++) {
    final type = rng.pickWeighted(eventTypes, baseW);
    final district = city.districts.isEmpty ? null : city.districts[rng.nextIntRange(0, city.districts.length - 1)];
    String? drugId;
    String desc;
    if (type == 'Drought') {
      final drug = rng.pickWeighted(drugCatalog, drugCatalog.map((d) => d.rarity).toList());
      drugId = drug.id;
      desc = district == null ? 'Drought today for ${drug.name}!' : 'Drought in ${district.name} for ${drug.name}!';
    } else {
      desc = district == null ? '$type today!' : '$type in ${district.name}!';
    }
    events.add(Event(type: type, districtId: district?.id ?? '', desc: desc, drugId: drugId));
  }
  // Rumor seeding moved out of provider to avoid side effects during build.
  // Occasionally create a multi-day global shortage
  // Global shortages persistence moved out of provider; we only surface events here if any.
  // Optionally: could derive a transient shortage event without persisting.
  // Weekly mutation
  // Weekly mutation persistence moved out of provider; avoid writes here.
  // Patrol sweeps: on every 3rd day, high-police districts have a chance to trigger a Sweep
  if (day % 3 == 0 && city.districts.isNotEmpty) {
    for (final d in city.districts) {
      if (d.policePresence >= 0.65) {
        final roll = rng.nextDoubleRange(0, 1);
        if (roll < 0.25) {
          events.add(Event(type: 'Patrol Sweep', districtId: d.id, desc: 'Increased patrols reported in ${d.name}.'));
        }
      }
    }
  }
  // Undercover stings: small chance daily in high heat, tagged to current district context
  try {
    final gs = ref.read(gameStateProvider);
    final heat = (gs['heat'] as num).toDouble();
    final metaRaw2 = gs['meta'];
    final meta2 = metaRaw2 is Map ? Map<String, dynamic>.from(metaRaw2) : <String, dynamic>{};
    final idx = (meta2['currentDistrict'] ?? 0) as int;
    if (heat >= 0.4 && idx >= 0 && idx < city.districts.length) {
      final roll = rng.nextDoubleRange(0, 1);
      if (roll < (0.05 + heat * 0.1)) {
        final d = city.districts[idx];
        events.add(Event(type: 'Undercover Sting', districtId: d.id, desc: 'Suspicious buyers are circling in ${d.name}.'));
      }
    }
  } catch (_) {}

  // Corruption probe: if you've been bribing repeatedly and the district is less corrupt, internal affairs watches
  try {
    final gs = ref.read(gameStateProvider);
    final metaRaw3 = gs['meta'];
    final meta3 = metaRaw3 is Map ? Map<String, dynamic>.from(metaRaw3) : <String, dynamic>{};
    final bribeStreak = (meta3['bribeStreak'] ?? 0) as int;
    final idx = (meta3['currentDistrict'] ?? 0) as int;
    if (bribeStreak >= 2 && idx >= 0 && idx < city.districts.length) {
      final d = city.districts[idx];
  final corr = (city.bonuses[d.id]?['corruption'] ?? 0.5);
      // Less corrupt => higher chance of probe
      final p = (0.08 + (0.5 - corr) * 0.2 + 0.03 * (bribeStreak - 1)).clamp(0.0, 0.25);
      if (rng.nextDoubleRange(0, 1) < p) {
        events.add(Event(type: 'Corruption Probe', districtId: d.id, desc: 'Internal Affairs probing in ${d.name}. Bribes may backfire.'));
      }
    }
  } catch (_) {}

  // Informant tip: when morale is low, a tip can leak to the cops in current district
  try {
    final crew = ref.read(crewProvider);
    final gs = ref.read(gameStateProvider);
    final idx = (gs['meta']['currentDistrict'] ?? 0) as int;
    if (idx >= 0 && idx < city.districts.length) {
      final d = city.districts[idx];
      final avgMorale = crew.crew.isEmpty ? 70 : (crew.crew.map((c) => c.morale).reduce((a, b) => a + b) / crew.crew.length);
      final p = avgMorale < 50 ? (0.05 + (50 - avgMorale) / 400.0).clamp(0.02, 0.2) : 0.0;
      if (p > 0 && rng.nextDoubleRange(0, 1) < p) {
        events.add(Event(type: 'Informant Tip', districtId: d.id, desc: 'Whispers say a tip reached the cops in ${d.name}.'));
      }
    }
  } catch (_) {}
  return events;
});
