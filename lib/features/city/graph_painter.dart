import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../state/city_provider.dart';

class GraphPainter extends CustomPainter {
  final CityGraph city;
  final bool bribedToday;
  final Map<String, int> influenceByDid;
  final Map<String, int> protectionByDid;
  final Set<String> rivalWarnDid;
  GraphPainter(this.city, {this.bribedToday = false, this.influenceByDid = const {}, this.protectionByDid = const {}, this.rivalWarnDid = const {}});
  @override
  void paint(Canvas canvas, Size size) {
    final nodePaint = Paint()
      ..color = Colors.deepPurple
      ..style = PaintingStyle.fill;
    final edgePaint = Paint()
      ..color = Colors.tealAccent
      ..strokeWidth = 4;
    final n = city.districts.length;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2.5;
    final angleStep = 2 * math.pi / n;
    final positions = <Offset>[];
    for (int i = 0; i < n; i++) {
      final angle = i * angleStep;
      positions.add(center + Offset(radius * math.cos(angle), radius * math.sin(angle)));
    }
    // Draw edges
    for (final edge in city.edges) {
      final i = city.districts.indexWhere((d) => d.id == edge.from);
      final j = city.districts.indexWhere((d) => d.id == edge.to);
      if (i >= 0 && j >= 0) {
        canvas.drawLine(positions[i], positions[j], edgePaint);
      }
    }
    // Draw nodes
    for (int i = 0; i < n; i++) {
      final did = city.districts[i].id;
      final infl = (influenceByDid[did] ?? 0).clamp(0, 100);
      final prot = (protectionByDid[did] ?? 0);
      final warn = rivalWarnDid.contains(did);
      // Base node
      canvas.drawCircle(positions[i], 32, nodePaint);
      // Control ring: hue shifts by influence; greenish when high, reddish when low
      final controlColor = Color.lerp(Colors.redAccent, Colors.greenAccent, infl / 100.0) ?? Colors.yellow;
      final controlPaint = Paint()
        ..color = controlColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      if (infl > 0) {
        canvas.drawCircle(positions[i], 36, controlPaint);
      }
      // Protection shield badge
      if (prot > 0) {
        final badgePaint = Paint()..color = Colors.tealAccent;
        final badgeCenter = positions[i] + const Offset(-24, -24);
        canvas.drawCircle(badgeCenter, 9, badgePaint);
      }
      // Rival warning halo
      if (warn) {
        final haloPaint = Paint()
          ..color = Colors.orangeAccent.withOpacity(0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6;
        canvas.drawCircle(positions[i], 42, haloPaint);
      }
      if (bribedToday) {
        final badgePaint = Paint()..color = Colors.greenAccent;
        final badgeCenter = positions[i] + const Offset(22, -22);
        canvas.drawCircle(badgeCenter, 8, badgePaint);
      }
      final textPainter = TextPainter(
        text: TextSpan(text: city.districts[i].name, style: const TextStyle(color: Colors.white, fontSize: 16)),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, positions[i] - Offset(textPainter.width / 2, 40));
    }
  }
  @override
  bool shouldRepaint(covariant GraphPainter old) =>
      old.city != city ||
      old.bribedToday != bribedToday ||
      old.influenceByDid != influenceByDid ||
      old.protectionByDid != protectionByDid ||
      old.rivalWarnDid != rivalWarnDid;
}
