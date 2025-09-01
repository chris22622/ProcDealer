import 'package:flutter/material.dart';
import '../../core/types.dart';
import '../../core/audio_service.dart';

class EventPopup extends StatelessWidget {
  final Event event;
  const EventPopup({Key? key, required this.event}) : super(key: key);

  IconData _iconFor(String type) {
    switch (type.toLowerCase()) {
      case 'festival':
        return Icons.celebration;
      case 'raid':
        return Icons.local_police;
      case 'drought':
        return Icons.wb_sunny;
      case 'gang war':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline;
    }
  }

  Color _colorFor(String type) {
    switch (type.toLowerCase()) {
      case 'festival':
        return Colors.lightBlueAccent;
      case 'raid':
        return Colors.redAccent;
      case 'drought':
        return Colors.orangeAccent;
      case 'gang war':
        return Colors.deepPurpleAccent;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(event.type);
    return Dialog(
      backgroundColor: Colors.black87,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.2), blurRadius: 16, spreadRadius: 2),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(_iconFor(event.type), color: color)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    event.type,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              event.desc,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Got it'),
              ),
            )
          ],
        ),
      ),
    );
  }
}

Future<void> showEventPopups(BuildContext context, List<Event> events) async {
  for (final e in events) {
  // Respect settings: play an alert for each event popup
  await AudioService.alert();
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => EventPopup(event: e),
    );
  }
}
