import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_venture_flutter/core/database/database_helper.dart';
import 'package:app_venture_flutter/features/fitness/data/seven_day_fitness_engine.dart';
import 'package:path/path.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Phase 4 Safe 7-Day Activity Dashboard Integration Tests', () {
    late Database db;

    setUp(() async {
      final dbPath = await databaseFactory.getDatabasesPath();
      final path = join(dbPath, 'test_phase4.db');
      await databaseFactory.deleteDatabase(path);

      DatabaseHelper.customDbPath = 'test_phase4.db';
      db = await DatabaseHelper.instance.database;
    });

    tearDown(() async {
      await DatabaseHelper.instance.close();
      DatabaseHelper.customDbPath = null;
    });

    test('1. Query latest seven_day_activity_assessments for specific user', () async {
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
        calculatedScore: 85.0,
        componentA: 25.0,
        componentB: 15.0,
        componentC: 10.0,
        componentE: 15.0,
        formulaVersion: 'v1.0-google-fit-7d',
        dataSource: 'Google Fit CSV',
        dataCompleteness: 'Complete (7 Days)',
        assessedAt: DateTime.now().toIso8601String(),
      );

      await db.insert('seven_day_activity_assessments', record.toMap());

      final rows = await db.query(
        'seven_day_activity_assessments',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'assessed_at DESC',
        limit: 1,
      );

      expect(rows.length, 1);
      final loaded = SevenDayFitnessAssessmentRecord.fromMap(rows.first);
      expect(loaded.calculatedScore, 85.0);
      expect(loaded.formulaVersion, 'v1.0-google-fit-7d');
    });

    test('2. Isolation between users when querying seven_day_activity_assessments', () async {
      final user1 = await db.insert('users', {
        'username': 'Hiker1',
        'email': 'hiker1@test.com',
        'password_hash': 'hash',
        'created_at': DateTime.now().toIso8601String(),
      });

      final user2 = await db.insert('users', {
        'username': 'Hiker2',
        'email': 'hiker2@test.com',
        'password_hash': 'hash',
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.insert('seven_day_activity_assessments', {
        'user_id': user1,
        'assessment_start_date': '2026-10-01',
        'assessment_end_date': '2026-10-07',
        'calculated_score': 80.0,
        'component_a': 20, 'component_b': 15, 'component_c': 10, 'component_e': 15,
        'formula_version': 'v1.0-google-fit-7d',
        'data_source': 'CSV',
        'data_completeness': 'Complete',
        'assessed_at': DateTime.now().toIso8601String(),
      });

      final rowsUser2 = await db.query(
        'seven_day_activity_assessments',
        where: 'user_id = ?',
        whereArgs: [user2],
      );

      expect(rowsUser2.isEmpty, true);
    });

    test('3. Legacy fitness_assessments data remains unchanged and accessible', () async {
      final userId = await db.insert('users', {
        'username': 'LegacyHiker',
        'email': 'legacy@test.com',
        'password_hash': 'hash',
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.insert('fitness_assessments', {
        'user_id': userId,
        'dataset_reference': 'legacy.csv',
        'calculated_score': 72.0,
        'fitness_level': 'Moderate',
        'assessed_at': DateTime.now().toIso8601String(),
      });

      final legacyRows = await db.query('fitness_assessments', where: 'user_id = ?', whereArgs: [userId]);
      expect(legacyRows.length, 1);
      expect(legacyRows.first['calculated_score'], 72.0);
    });
  });
}
