import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class FlameRoot extends FlameGame {
  @override
  Color backgroundColor() => const Color(0xFF181A20);

  @override
  Future<void> onLoad() async {
    // Minimal placeholder: draw a few animated shapes for event feedback
  }
}

class FlameOverlay extends StatelessWidget {
  const FlameOverlay({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: GameWidget(game: FlameRoot()),
    );
  }
}
