import 'package:flutter_test/flutter_test.dart';
import 'package:proc_dealer/core/rng.dart';

void main() {
  test('pickWeighted returns items with correct probability', () {
    final rng = Rng(42);
    final items = ['a', 'b', 'c'];
    final weights = [0.1, 0.8, 0.1];
    final results = <String, int>{'a': 0, 'b': 0, 'c': 0};
    for (int i = 0; i < 1000; i++) {
      final pick = rng.pickWeighted(items, weights);
      results[pick] = results[pick]! + 1;
    }
    expect(results['b']! > results['a']!, true);
    expect(results['b']! > results['c']!, true);
  });

  test('nextDoubleRange returns value in range', () {
    final rng = Rng(123);
    for (int i = 0; i < 100; i++) {
      final v = rng.nextDoubleRange(-2, 2);
      expect(v >= -2 && v <= 2, true);
    }
  });
}
