import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_venture_flutter/core/database/database_helper.dart';
import 'package:app_venture_flutter/features/fitness/data/fitness_score_calculator.dart';
import 'package:app_venture_flutter/features/fitness/data/fitness_profile_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    DatabaseHelper.customDbPath = 'test_phase5_${DateTime.now().microsecondsSinceEpoch}.db';
  });

  tearDown(() async {
    try {
      await DatabaseHelper.instance.close();
    } catch (_) {}
  });

  test('CSV Parsing Test with Demo Dataset', () {
    final records = FitnessScoreCalculator.parseCsv(FitnessScoreCalculator.demoCsvContent);
    expect(records.isNotEmpty, isTrue);
    expect(records.first.stepCount, equals(8500));
    expect(records.first.heartPoints, equals(25.0));
  });

  test('Seven-Component Fitness Score Calculation Test', () {
    final records = FitnessScoreCalculator.parseCsv(FitnessScoreCalculator.demoCsvContent);
    final result = FitnessScoreCalculator.calculate(
      records: records,
      heightCm: 178.0,
      weightKg: 72.0,
    );

    expect(result.totalScore, greaterThan(0));
    expect(result.totalScore, lessThanOrEqualTo(100.0));
    expect(result.componentA, greaterThanOrEqualTo(0));
    expect(result.componentA, lessThanOrEqualTo(25));
    expect(result.componentB, greaterThanOrEqualTo(0));
    expect(result.componentB, lessThanOrEqualTo(15));
    expect(result.componentC, greaterThanOrEqualTo(0));
    expect(result.componentC, lessThanOrEqualTo(10));
    expect(result.componentD, greaterThanOrEqualTo(0));
    expect(result.componentD, lessThanOrEqualTo(15));
    expect(result.componentE, greaterThanOrEqualTo(0));
    expect(result.componentE, lessThanOrEqualTo(15));
    expect(result.componentF, greaterThanOrEqualTo(0));
    expect(result.componentF, lessThanOrEqualTo(10));
    expect(result.componentG, greaterThanOrEqualTo(0));
    expect(result.componentG, lessThanOrEqualTo(10));
  });

  test('SQLite Fitness Assessment Persistence and User Isolation Test', () async {
    final dbHelper = DatabaseHelper.instance;
    final profileRepo = FitnessProfileRepository(dbHelper);

    final user1Id = await profileRepo.getOrCreateUserIdByEmail('user1@venture.com', 'User One');
    final user2Id = await profileRepo.getOrCreateUserIdByEmail('user2@venture.com', 'User Two');

    final db = await dbHelper.database;

    // Save assessment for user 1
    await db.insert('fitness_assessments', {
      'user_id': user1Id,
      'dataset_reference': 'DEMO_28Day_Smartwatch_Dataset.csv',
      'calculated_score': 85.0,
      'fitness_level': 'Good',
      'assessed_at': DateTime.now().toIso8601String(),
    });

    final res1 = await db.query('fitness_assessments', where: 'user_id = ?', whereArgs: [user1Id]);
    final res2 = await db.query('fitness_assessments', where: 'user_id = ?', whereArgs: [user2Id]);

    expect(res1.length, equals(1));
    expect(res1.first['calculated_score'], equals(85.0));
    expect(res2.isEmpty, isTrue); // User 2 data isolation
  });
}
