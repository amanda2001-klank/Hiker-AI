import 'package:flutter_test/flutter_test.dart';
import 'package:app_venture_flutter/features/fitness/data/seven_day_fitness_engine.dart';

void main() {
  group('Phase 8E Android File Import and Calculation Reliability Tests', () {
    test('1. Different datasets produce distinct scores', () {
      const csvA = 'date,heart points,move minutes,steps\n'
          '2026-10-01,10,20,5000\n'
          '2026-10-02,12,22,5200\n'
          '2026-10-03,15,25,5500\n'
          '2026-10-04,14,24,5300\n'
          '2026-10-05,11,21,5100\n'
          '2026-10-06,16,28,5800\n'
          '2026-10-07,13,23,5200\n';

      const csvB = 'date,heart points,move minutes,steps\n'
          '2026-10-01,45,60,12000\n'
          '2026-10-02,50,65,12500\n'
          '2026-10-03,48,62,12200\n'
          '2026-10-04,52,70,13000\n'
          '2026-10-05,46,60,11900\n'
          '2026-10-06,55,75,13500\n'
          '2026-10-07,49,63,12100\n';

      final actsA = SevenDayFitnessEngine.parseCsv(csvA);
      final actsB = SevenDayFitnessEngine.parseCsv(csvB);

      final resA = SevenDayFitnessEngine.calculate(activities: actsA);
      final resB = SevenDayFitnessEngine.calculate(activities: actsB);

      expect(resA.finalActivityScore, isNot(equals(resB.finalActivityScore)));
      expect(resB.finalActivityScore, greaterThan(resA.finalActivityScore));
    });

    test('2. Empty or invalid CSV content yields zero score or empty activities', () {
      const emptyCsv = 'date,heart points,move minutes,steps\n';
      final acts = SevenDayFitnessEngine.parseCsv(emptyCsv);
      expect(acts.isEmpty, true);
    });
  });
}
