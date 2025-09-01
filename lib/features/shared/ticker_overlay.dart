import 'package:flutter/material.dart';

class TickerOverlay extends StatefulWidget {
  final String text;
  const TickerOverlay({Key? key, required this.text}) : super(key: key);
  @override
  State<TickerOverlay> createState() => _TickerOverlayState();
}

class _TickerOverlayState extends State<TickerOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<Offset> _offset;
  late Animation<double> _opacity;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _offset = Tween(begin: const Offset(0, 1), end: const Offset(0, 0)).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
    _opacity = CurvedAnimation(parent: _c, curve: Curves.easeIn);
    _c.forward();
  }
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: SlideTransition(
        position: _offset,
        child: FadeTransition(
          opacity: _opacity,
          child: Chip(
            label: Text(widget.text, style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.green.withOpacity(0.2),
            avatar: const Icon(Icons.attach_money, color: Colors.green),
          ),
        ),
      ),
    );
  }
}
