import 'dart:math';

class Rng {
  final Random _random;
  Rng(int seed) : _random = Random(seed);

  double nextDoubleRange(double min, double max) {
    return min + _random.nextDouble() * (max - min);
  }

  int nextIntRange(int min, int max) {
    return min + _random.nextInt(max - min + 1);
  }

  T pickWeighted<T>(List<T> items, List<double> weights) {
    assert(items.length == weights.length && items.isNotEmpty);
    final total = weights.reduce((a, b) => a + b);
    final r = _random.nextDouble() * total;
    double sum = 0;
    for (int i = 0; i < items.length; i++) {
      sum += weights[i];
      if (r < sum) return items[i];
    }
    return items.last;
  }
}
