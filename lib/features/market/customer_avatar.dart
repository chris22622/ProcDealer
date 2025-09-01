import 'package:flutter/material.dart';

class CustomerAvatar extends StatelessWidget {
  final String type;
  const CustomerAvatar({Key? key, required this.type}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    switch (type) {
      case 'Loyal':
        icon = Icons.emoji_emotions;
        color = Colors.greenAccent;
        break;
      case 'Whale':
        icon = Icons.attach_money;
        color = Colors.amberAccent;
        break;
      case 'Sketchy':
        icon = Icons.visibility_off;
        color = Colors.redAccent;
        break;
      default:
        icon = Icons.person;
        color = Colors.grey;
    }
    return CircleAvatar(
      backgroundColor: color.withOpacity(0.2),
      child: Icon(icon, color: color, size: 32),
      radius: 24,
    );
  }
}
