import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/city_provider.dart';
import '../../state/game_state.dart';
import 'graph_painter.dart';
import 'dart:math' as math;
import 'district_detail_dialog.dart';

class CityScreen extends ConsumerWidget {
  const CityScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final city = ref.watch(cityProvider);
  final gs = ref.watch(gameStateProvider);
  final bribed = (gs['meta']['policeBribedToday'] ?? false) == true;
  final inflRaw = (gs['meta']['influenceByDistrict'] ?? const <String, int>{});
  final protRaw = (gs['meta']['protectionByDistrict'] ?? const <String, int>{});
  final infl = inflRaw is Map ? Map<String, int>.from(inflRaw.map((k, v) => MapEntry(k.toString(), (v as num).toInt()))) : <String, int>{};
  final prot = protRaw is Map ? Map<String, int>.from(protRaw.map((k, v) => MapEntry(k.toString(), (v as num).toInt()))) : <String, int>{};
  // Rival warnings from queued events for next day or low influence
  final events = (gs['meta']['eventsForDay'] as List<dynamic>? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  final warn = <String>{
    ...events.where((e) => (e['type'] ?? '') == 'Rival').map((e) => (e['districtId'] ?? '').toString()),
    ...infl.entries.where((e) => e.value <= 15 && e.value > 0).map((e) => e.key),
  }..removeWhere((e) => e.isEmpty);
    if (city.districts.isEmpty) {
      return Center(child: Text('No districts available today', style: Theme.of(context).textTheme.titleLarge));
    }
    return GestureDetector(
      onTapUp: (details) {
        // Simple hit test: find closest node
        final renderObject = context.findRenderObject();
        if (renderObject is! RenderBox) return;
  final box = renderObject;
  final local = box.globalToLocal(details.globalPosition);
        final n = city.districts.length;
        final center = Offset(box.size.width / 2, 200);
        final radius = box.size.shortestSide / 2.5;
        final angleStep = n == 0 ? 0.0 : 2 * 3.1415 / n;
        for (int i = 0; i < n; i++) {
          final angle = i * angleStep;
          final pos = center + Offset(radius * math.cos(angle), radius * math.sin(angle));
      if ((local - pos).distance < 40) {
            showDialog(
              context: context,
        builder: (_) => DistrictDetailDialog(district: city.districts[i], index: i),
            );
            break;
          }
        }
      },
      child: CustomPaint(
        painter: GraphPainter(city, bribedToday: bribed, influenceByDid: infl, protectionByDid: prot, rivalWarnDid: warn),
        child: Container(
          height: 400,
          width: double.infinity,
          child: Center(
            child: Text('Tap a district to travel', style: Theme.of(context).textTheme.titleLarge),
          ),
        ),
      ),
    );
  }
}
