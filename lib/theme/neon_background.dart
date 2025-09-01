import 'dart:math' as math;
import 'package:flutter/material.dart';

class NeonBackground extends StatefulWidget {
  final double speed; // 0.1..1.0
  final double intensity; // 0..1 glow strength
  const NeonBackground({Key? key, this.speed = 0.25, this.intensity = 0.6}) : super(key: key);

  @override
  State<NeonBackground> createState() => _NeonBackgroundState();
}

class _NeonBackgroundState extends State<NeonBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 16))
      ..addListener(() => setState(() {}))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _NeonPainter(t: _ctrl.value, intensity: widget.intensity, speed: widget.speed),
        size: Size.infinite,
      ),
    );
  }
}

class _NeonPainter extends CustomPainter {
  final double t; // 0..1
  final double speed;
  final double intensity;
  _NeonPainter({required this.t, required this.intensity, required this.speed});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    // Base deep gradient
    final bg = Rect.fromLTWH(0, 0, w, h);
    final g1 = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: const [Color(0xFF14151B), Color(0xFF1B0E27), Color(0xFF0E1B1A)],
      stops: const [0.0, 0.6, 1.0],
    );
    final pBg = Paint()..shader = g1.createShader(bg);
    canvas.drawRect(bg, pBg);

    // Animated glow blobs
    final now = t * 2 * math.pi * speed;
    final blobs = [
      _blob(w, h, now + 0.0, const Color(0xFF7C4DFF)), // deepPurpleAccent
      _blob(w, h, now + 1.7, const Color(0xFF00E5FF)), // cyanAccent
      _blob(w, h, now + 3.1, const Color(0xFF64FFDA)), // tealAccent
    ];
    for (final b in blobs) {
      final center = Offset(b.cx, b.cy);
      final r = b.r;
      final grad = RadialGradient(
        colors: [b.color.withOpacity(0.55 * intensity), b.color.withOpacity(0.0)],
        stops: const [0.0, 1.0],
      );
      final rect = Rect.fromCircle(center: center, radius: r);
      final paint = Paint()
        ..shader = grad.createShader(rect)
        ..blendMode = BlendMode.plus; // additive glow
      canvas.drawCircle(center, r, paint);
    }

    // Subtle vignette
    final vignette = RadialGradient(
      colors: [Colors.transparent, Colors.black.withOpacity(0.25)],
      stops: const [0.6, 1.0],
    );
    final pV = Paint()..shader = vignette.createShader(Rect.fromCircle(center: Offset(w * 0.5, h * 0.55), radius: h));
    canvas.drawRect(bg, pV);
  }

  _Blob _blob(double w, double h, double phase, Color color) {
    final t1 = (math.sin(phase * 0.9) + 1) / 2; // 0..1
    final t2 = (math.cos(phase * 1.3) + 1) / 2; // 0..1
    final cx = lerpDouble(w * 0.15, w * 0.85, t1);
    final cy = lerpDouble(h * 0.15, h * 0.85, t2);
    final r = lerpDouble(math.min(w, h) * 0.25, math.min(w, h) * 0.45, (t1 + t2) / 2);
    return _Blob(cx, cy, r, color);
  }

  double lerpDouble(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(covariant _NeonPainter oldDelegate) => oldDelegate.t != t || oldDelegate.intensity != intensity || oldDelegate.speed != speed;
}

class _Blob {
  final double cx, cy, r;
  final Color color;
  _Blob(this.cx, this.cy, this.r, this.color);
}
