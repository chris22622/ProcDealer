import 'package:flutter/material.dart';

class RiskMeter extends StatelessWidget {
  final double risk; // 0.0 to 1.0
  const RiskMeter({Key? key, required this.risk}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color color;
    if (risk < 0.3) {
      color = Colors.greenAccent;
    } else if (risk < 0.7) {
      color = Colors.orangeAccent;
    } else {
      color = Colors.redAccent;
    }
    return Row(
      children: [
        Icon(Icons.warning, color: color),
        Expanded(
          child: LinearProgressIndicator(
            value: risk,
            backgroundColor: Colors.grey[800],
            color: color,
            minHeight: 12,
          ),
        ),
        Text('${(risk * 100).toStringAsFixed(0)}%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
