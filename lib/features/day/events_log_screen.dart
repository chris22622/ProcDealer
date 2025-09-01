import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/event_provider.dart';

class EventsLogScreen extends ConsumerWidget {
  const EventsLogScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Events Log')),
      body: ListView.separated(
        itemCount: events.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final e = events[i];
          return ListTile(
            leading: const Icon(Icons.event_note),
            title: Text(e.type),
            subtitle: Text(e.desc),
          );
        },
      ),
    );
  }
}
