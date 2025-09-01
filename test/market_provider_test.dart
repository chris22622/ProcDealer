import 'package:flutter_test/flutter_test.dart';
import 'package:proc_dealer/core/balance.dart';
import 'package:proc_dealer/core/rng.dart';
import 'package:proc_dealer/data/drug_catalog.dart';

void main() {
  test('Market price is within volatility cap', () {
    final day = 1;
    final rng = Rng(day);
    for (final drug in drugCatalog) {
      final volatility = Balance.volCap * (rng.nextDoubleRange(-1, 1));
      final price = (drug.basePrice * (1 + volatility)).round();
      expect(price >= 0, true);
      expect(price <= drug.basePrice * (1 + Balance.volCap), true);
      expect(price >= drug.basePrice * (1 - Balance.volCap), true);
    }
  });
}
