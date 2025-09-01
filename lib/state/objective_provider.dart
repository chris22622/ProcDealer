import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'game_state.dart';

class Objective {
  final String id;
  final String desc;
  final String kind; // e.g., 'sell_any', 'bank_ge'
  final int target; // used for thresholds
  final int reward; // cash reward
  final bool done;
  const Objective({
    required this.id,
    required this.desc,
    required this.kind,
    required this.target,
    required this.reward,
    this.done = false,
  });

  Objective copyWith({bool? done}) => Objective(
        id: id,
        desc: desc,
        kind: kind,
        target: target,
        reward: reward,
        done: done ?? this.done,
      );

  factory Objective.fromJson(Map<String, dynamic> j) => Objective(
        id: j['id'],
        desc: j['desc'],
        kind: j['kind'],
        target: j['target'] ?? 0,
        reward: j['reward'] ?? 0,
        done: j['done'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'desc': desc,
        'kind': kind,
        'target': target,
        'reward': reward,
        'done': done,
      };
}

List<Objective> _generateForDay(int day) {
  // Two light objectives per day
  return [
    Objective(
      id: 'sell_any_$day',
      desc: 'Make any sale today',
      kind: 'sell_any',
      target: 1,
      reward: 100,
    ),
    Objective(
      id: 'bank_1000_$day',
      desc: 'End day with \$1,000 in the bank',
      kind: 'bank_ge',
      target: 1000,
      reward: 150,
    ),
  ];
}

final objectivesProvider = Provider<List<Objective>>((ref) {
  final state = ref.watch(gameStateProvider);
  final day = state['day'] as int;
  final metaRaw = state['meta'];
  final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
  final raw = meta['objectives'];
  List<Objective> list;
  if (raw is List && raw.isNotEmpty) {
    list = raw.map((e) => Objective.fromJson(Map<String, dynamic>.from(e))).toList();
  } else {
    list = _generateForDay(day);
    Future.microtask(() => ref.read(gameStateProvider.notifier).setObjectivesJson(
          list.map((e) => e.toJson()).toList(),
        ));
  }
  return list;
});
