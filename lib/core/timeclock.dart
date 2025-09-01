import 'package:flutter_riverpod/flutter_riverpod.dart';

class DayClock extends StateNotifier<int> {
  DayClock() : super(1);

  void advanceDay() => state++;
}
