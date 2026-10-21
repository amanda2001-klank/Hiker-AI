import 'package:flutter_test/flutter_test.dart';
import 'package:app_venture_flutter/features/fitness/data/seven_day_fitness_engine.dart';
import 'package:app_venture_flutter/features/fitness/data/fitness_score_calculator.dart';

void main() {
  group('Phase 2B Integration & Validation Tests', () {
    test('1. Legacy calculator remains fully functional', () {
      final records = FitnessScoreCalculator.parseCsv(FitnessScoreCalculator.demoCsvContent);
      final result = FitnessScoreCalculator.calculate(records: records, heightCm: 175.0, weightKg: 70.0);
      expect(result.totalScore, greaterThan(0));
      expect(result.fitnessLevel, isNotEmpty);
    });

    test('2. New 7-day CSV input works with SevenDayFitnessEngine', () {
      final activities = SevenDayFitnessEngine.parseCsv(FitnessScoreCalculator.demoCsvContent);
      final aggregate = SevenDayFitnessEngine.calculate(activities: activities);
      expect(aggregate.finalActivityScore, greaterThan(0));
      expect(aggregate.formulaVersion, 'v1.0-google-fit-7d');
    });

    test('3. A/B/C/E breakdown components are calculated correctly', () {
      final activities = List.generate(7, (i) => GoogleFitDailyActivity(
        date: DateTime(2026, 10, i + 1),
        heartPoints: 30.0,
        moveMinutes: 40.0,
        stepCount: 8500,
        isMissing: false,
      ));

      final aggregate = SevenDayFitnessEngine.calculate(activities: activities);
      expect(aggregate.componentA, 25.0);
      expect(aggregate.componentB, 15.0);
      expect(aggregate.componentC, greaterThan(0));
      expect(aggregate.componentE, 15.0);
      expect(aggregate.isComplete, true);
    });

    test('4. Missing Heart Points or incomplete days flag data quality warnings', () {
      final activities = [
        GoogleFitDailyActivity(date: DateTime(2026, 10, 1), heartPoints: 0, moveMinutes: 0, stepCount: 0, isMissing: true),
      ];

      final aggregate = SevenDayFitnessEngine.calculate(activities: activities);
      expect(aggregate.isComplete, false);
      expect(aggregate.dataQualityWarnings.isNotEmpty, true);
    });

    test('5. Zero activity yields zero score cleanly', () {
      final activities = List.generate(7, (i) => GoogleFitDailyActivity(
        date: DateTime(2026, 10, i + 1),
        heartPoints: 0.0,
        moveMinutes: 0.0,
        stepCount: 0,
        isMissing: false,
      ));

      final aggregate = SevenDayFitnessEngine.calculate(activities: activities);
      expect(aggregate.finalActivityScore, 0.0);
      expect(aggregate.activeDays7d, 0);
    });
  });
}
