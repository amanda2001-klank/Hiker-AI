import 'package:flutter_test/flutter_test.dart';
import 'package:app_venture_flutter/features/fitness/data/seven_day_fitness_engine.dart';

void main() {
  group('SevenDayFitnessEngine Tests', () {
    test('1. Correct formula results with normal 7-day activity', () {
      final activities = List.generate(7, (i) => GoogleFitDailyActivity(
        date: DateTime(2026, 10, i + 1),
        heartPoints: 20.0,
        moveMinutes: 35.0,
        stepCount: 8000,
        isMissing: false,
      ));

      final result = SevenDayFitnessEngine.calculate(activities: activities);
      expect(result.hp7d, 140.0);
      expect(result.moveMin7d, 245.0);
      expect(result.stepsAvg7d, 8000.0);
      expect(result.activeDays7d, 7);
      expect(result.finalActivityScore, greaterThan(0));
      expect(result.finalActivityScore, lessThanOrEqualTo(100.0));
      expect(result.dataQualityWarnings, isEmpty);
    });

    test('2. Zero activity yields zero score', () {
      final activities = List.generate(7, (i) => GoogleFitDailyActivity(
        date: DateTime(2026, 10, i + 1),
        heartPoints: 0.0,
        moveMinutes: 0.0,
        stepCount: 0,
        isMissing: false,
      ));

      final result = SevenDayFitnessEngine.calculate(activities: activities);
      expect(result.finalActivityScore, 0.0);
    });

    test('3. Missing Heart Points handled gracefully', () {
      final activities = [
        GoogleFitDailyActivity(date: DateTime(2026, 10, 1), heartPoints: 0.0, moveMinutes: 35.0, stepCount: 8000, isMissing: true),
        ...List.generate(6, (i) => GoogleFitDailyActivity(
          date: DateTime(2026, 10, i + 2),
          heartPoints: 20.0,
          moveMinutes: 35.0,
          stepCount: 8000,
          isMissing: false,
        )),
      ];

      final result = SevenDayFitnessEngine.calculate(activities: activities);
      expect(result.dataQualityWarnings.isNotEmpty, true);
    });

    test('4. CSV Parser correctly parses CSV content', () {
      const csv = 'date,heart points,move minutes,steps\n2026-10-01,25,45,9000\n2026-10-02,30,50,10000';
      final parsed = SevenDayFitnessEngine.parseCsv(csv);
      expect(parsed.length, 2);
      expect(parsed[0].heartPoints, 25.0);
      expect(parsed[0].stepCount, 9000);
    });

    test('5. Score boundaries clamp between 0 and 100', () {
      final activities = List.generate(7, (i) => GoogleFitDailyActivity(
        date: DateTime(2026, 10, i + 1),
        heartPoints: 500.0,
        moveMinutes: 300.0,
        stepCount: 25000,
        isMissing: false,
      ));

      final result = SevenDayFitnessEngine.calculate(activities: activities);
      expect(result.finalActivityScore, 100.0);
    });
  });
}
