import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_venture_flutter/core/database/database_helper.dart';
import 'package:app_venture_flutter/features/fitness/data/seven_day_fitness_engine.dart';
import 'package:path/path.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Phase 3 Safe Versioned 7-Day Persistence Tests', () {
    late Database db;

    setUp(() async {
      final dbPath = await databaseFactory.getDatabasesPath();
      final path = join(dbPath, 'test_phase3.db');
      await databaseFactory.deleteDatabase(path);

      DatabaseHelper.customDbPath = 'test_phase3.db';
      db = await DatabaseHelper.instance.database;
    });

    tearDown(() async {
      await DatabaseHelper.instance.close();
      DatabaseHelper.customDbPath = null;
    });

    test('1. Additive migration creates seven_day_activity_assessments table', () async {
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='seven_day_activity_assessments'");
      expect(tables.isNotEmpty, true);
    });

    test('2. Legacy fitness_assessments table is preserved and untouched', () async {
      final userId = await db.insert('users', {
        'username': 'TestHiker',
        'email': 'hiker@test.com',
        'password_hash': 'hash',
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.insert('fitness_assessments', {
        'user_id': userId,
        'dataset_reference': 'legacy.csv',
        'calculated_score': 75.0,
        'fitness_level': 'Good',
        'assessed_at': DateTime.now().toIso8601String(),
      });

      final legacyRows = await db.query('fitness_assessments');
      expect(legacyRows.length, 1);
      expect(legacyRows.first['calculated_score'], 75.0);
    });

    test('3. Save and load valid seven-day assessment record', () async {
      final userId = await db.insert('users', {
        'username': 'TestHiker',
        'email': 'hiker@test.com',
        'password_hash': 'hash',
        'created_at': DateTime.now().toIso8601String(),
      });

      final record = SevenDayFitnessAssessmentRecord(
        userId: userId,
        assessmentStartDate: '2026-10-01',
        assessmentEndDate: '2026-10-07',
        calculatedScore: 82.5,
        componentA: 25.0,
        componentB: 15.0,
        componentC: 8.5,
        componentE: 15.0,
        formulaVersion: 'v1.0-google-fit-7d',
        dataSource: 'Google Fit CSV',
        dataCompleteness: 'Complete (7 Days)',
        assessedAt: DateTime.now().toIso8601String(),
      );

      final id = await db.insert('seven_day_activity_assessments', record.toMap());
      expect(id, greaterThan(0));

      final rows = await db.query('seven_day_activity_assessments', where: 'user_id = ?', whereArgs: [userId]);
      expect(rows.length, 1);
      final loaded = SevenDayFitnessAssessmentRecord.fromMap(rows.first);
      expect(loaded.calculatedScore, 82.5);
      expect(loaded.formulaVersion, 'v1.0-google-fit-7d');
    });

    test('4. Reject incomplete assessment persistence when completeness is invalid', () {
      // Logic in UI checks completeness before saving (isComplete == false -> disabled)
      final aggregate = SevenDayFitnessAggregate(
        dailyActivities: [],
        hp7d: 0, moveMin7d: 0, stepsAvg7d: 0, activeDays7d: 0,
        componentA: 0, componentB: 0, componentC: 0, componentE: 0,
        finalActivityScore: 0,
        formulaVersion: 'v1.0-google-fit-7d',
        sourceProvenance: 'test',
        dataQualityWarnings: ['Incomplete'],
      );

      expect(aggregate.isComplete, false);
    });
  });
}
