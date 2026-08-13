import 'package:eyzo/core/utils/glasses_timing.dart';

void main() {
  for (var s = 1; s <= 10; s++) {
    // ignore: avoid_print
    print('speed=$s scroll=${scrollStepIntervalMs(s)}ms blink=${blinkHalfPeriodMs(s)}ms');
  }
}
