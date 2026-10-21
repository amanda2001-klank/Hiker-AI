import 'package:flutter_test/flutter_test.dart';
import 'package:app_venture_flutter/features/fitness/data/seven_day_fitness_engine.dart';

void main() {
  group('Phase 8H Move Minutes Header Fix & Regression Tests', () {
    test('1. Parse exact provided CSV header with "Move Minutes count" and "Step count"', () {
      const csvContent = 'Date,Move Minutes count,Calories (kcal),Distance (m),Heart Points,Heart Minutes,Average heart rate (bpm),Max heart rate (bpm),Min heart rate (bpm),Average speed (m/s),Max speed (m/s),Min speed (m/s),Step count,Average weight (kg),Max weight (kg),Min weight (kg),Walking duration (ms),Running duration (ms)\n'
          '2026-10-08,40,,,10,10,,,,,,,6000,,,,,';

      final records = SevenDayFitnessEngine.parseCsv(csvContent);
      expect(records.length, 1);
      expect(records.first.date.year, 2026);
      expect(records.first.date.month, 10);
      expect(records.first.date.day, 8);
      expect(records.first.moveMinutes, 40.0);
      expect(records.first.heartPoints, 10.0);
      expect(records.first.stepCount, 6000);
    });

    test('2. Seven-day synthetic HIGH CSV extracts all seven days correctly', () {
      const csvHigh = 'Date,Move Minutes count,Heart Points,Step count\n'
          '2026-10-01,45,25,8500\n'
          '2026-10-02,50,30,9200\n'
          '2026-10-03,40,20,7800\n'
          '2026-10-04,55,35,10500\n'
          '2026-10-05,42,22,8100\n'
          '2026-10-06,48,28,9000\n'
          '2026-10-07,60,40,11500\n';

      final records = SevenDayFitnessEngine.parseCsv(csvHigh);
      expect(records.length, 7);
      final aggregate = SevenDayFitnessEngine.calculate(activities: records);
      expect(aggregate.isComplete, true);
      expect(aggregate.finalActivityScore, greaterThan(0));
    });

    test('3. Invalid dates are strictly rejected rather than parsed as DateTime.now()', () {
      const csvInvalidDate = 'Date,Move Minutes count,Heart Points,Step count\n'
          'invalid-date,40,10,6000\n'
          '2026-10-08,40,10,6000\n';

      final records = SevenDayFitnessEngine.parseCsv(csvInvalidDate);
      expect(records.length, 1); // invalid-date rejected
      expect(records.first.date.day, 8);
    });

    test('4. Genuine zero-activity days remain valid', () {
      const csvZero = 'Date,Move Minutes count,Heart Points,Step count\n'
          '2026-10-08,0,0,0\n';

      final records = SevenDayFitnessEngine.parseCsv(csvZero);
      expect(records.length, 1);
      expect(records.first.isMissing, false);
      expect(records.first.stepCount, 0);
    });
  });
}
