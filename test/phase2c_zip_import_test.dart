import 'package:flutter_test/flutter_test.dart';
import 'package:app_venture_flutter/features/fitness/data/seven_day_fitness_engine.dart';
import 'package:app_venture_flutter/features/fitness/data/fitness_score_calculator.dart';

void main() {
  group('Phase 2C ZIP & CSV Import Verification Tests', () {
    test('1. Valid direct CSV import and 7-day calculation', () {
      const csvData = 'date,heart points,move minutes,steps\n'
          '2026-10-01,20,35,7500\n'
          '2026-10-02,22,40,8200\n'
          '2026-10-03,18,30,7000\n'
          '2026-10-04,25,45,9100\n'
          '2026-10-05,20,35,7800\n'
          '2026-10-06,28,50,9500\n'
          '2026-10-07,24,42,8800\n';

      final activities = SevenDayFitnessEngine.parseCsv(csvData);
      expect(activities.length, 7);
      final aggregate = SevenDayFitnessEngine.calculate(activities: activities);
      expect(aggregate.isComplete, true);
      expect(aggregate.finalActivityScore, greaterThan(0));
    });

    test('2. Missing daily metrics flag data quality warnings and incomplete status', () {
      final activities = [
        GoogleFitDailyActivity(date: DateTime(2026, 10, 1), heartPoints: 0, moveMinutes: 0, stepCount: 0, isMissing: true),
      ];

      final aggregate = SevenDayFitnessEngine.calculate(activities: activities);
      expect(aggregate.isComplete, false);
      expect(aggregate.dataQualityWarnings.isNotEmpty, true);
    });

    test('3. Legacy mode regression test remains functional', () {
      final records = FitnessScoreCalculator.parseCsv(FitnessScoreCalculator.demoCsvContent);
      expect(records.isNotEmpty, true);
      final result = FitnessScoreCalculator.calculate(records: records, heightCm: 170.0, weightKg: 68.0);
      expect(result.totalScore, greaterThan(0));
    });
  });
}
