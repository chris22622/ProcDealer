import 'package:flutter/material.dart';
import 'dart:math';

class AnimatedConfetti extends StatefulWidget {
  final bool trigger;
  const AnimatedConfetti({Key? key, required this.trigger}) : super(key: key);
  @override
  State<AnimatedConfetti> createState() => _AnimatedConfettiState();
}

class _AnimatedConfettiState extends State<AnimatedConfetti> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Offset> _particles = [];
  final int _count = 24;
  final Random _rand = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    if (widget.trigger) _controller.forward();
    for (int i = 0; i < _count; i++) {
      _particles.add(Offset(_rand.nextDouble() * 2 - 1, _rand.nextDouble() * 2 - 1));
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedConfetti oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Expand to fill available space; avoid infinite size in CustomPaint
          return SizedBox.expand(
            child: CustomPaint(
              painter: _ConfettiPainter(_controller.value, _particles),
            ),
          );
        },
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<Offset> particles;
  _ConfettiPainter(this.progress, this.particles);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;
    for (final offset in particles) {
      paint.color = Colors.primaries[(offset.dx * 10).abs().toInt() % Colors.primaries.length];
      final p = center + offset * 120 * progress;
      canvas.drawCircle(p, 8 * (1 - progress), paint);
    }
  }
  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.progress != progress;
}
