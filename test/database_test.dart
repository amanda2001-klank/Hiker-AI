import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_venture_flutter/core/database/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    DatabaseHelper.customDbPath = 'test_db_${DateTime.now().microsecondsSinceEpoch}.db';
  });

  tearDown(() async {
    try {
      await DatabaseHelper.instance.close();
    } catch (_) {}
  });

  test('Verify all 10 core tables and their exact columns exist', () async {
    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;

    // Verify foreign key support is enabled
    final fkResult = await db.rawQuery('PRAGMA foreign_keys;');
    expect(fkResult.first['foreign_keys'], equals(1));

    const expectedSchema = {
      'users': ['id', 'username', 'email', 'password_hash', 'profile_image_url', 'created_at'],
      'fitness_profiles': ['id', 'user_id', 'full_name', 'age', 'gender', 'height_cm', 'weight_kg', 'bmi', 'medical_history', 'physical_limitations', 'fitness_notes', 'updated_at'],
      'experience_assessments': ['id', 'user_id', 'q1_answer', 'q2_answer', 'q3_answer', 'q4_answer', 'calculated_score', 'experience_level', 'assessed_at'],
      'fitness_assessments': ['id', 'user_id', 'dataset_reference', 'calculated_score', 'fitness_level', 'assessed_at'],
      'connected_devices': ['id', 'user_id', 'device_name', 'device_address', 'device_type', 'is_connected', 'last_sync_time'],
      'daily_activities': ['id', 'user_id', 'date', 'steps', 'calories_burned', 'distance_km', 'avg_heart_rate'],
      'trails': ['id', 'name', 'description', 'difficulty', 'distance_km', 'elevation_gain_m', 'estimated_duration_mins', 'route_geometry'],
      'hiking_sessions': ['id', 'user_id', 'trail_id', 'start_time', 'end_time', 'status', 'current_heart_rate', 'distance_covered_km', 'calories_burned'],
      'hiking_history': ['id', 'user_id', 'hiking_session_id', 'summary_notes', 'max_heart_rate', 'max_elevation_m', 'completed_at'],
      'weather_cache': ['id', 'location_name', 'latitude', 'longitude', 'temperature_celsius', 'weather_condition', 'humidity_percent', 'cached_at'],
    };

    for (final entry in expectedSchema.entries) {
      final tableName = entry.key;
      final expectedColumns = entry.value;

      final tableInfo = await db.rawQuery('PRAGMA table_info($tableName);');
      expect(tableInfo, isNotEmpty, reason: 'Table $tableName should exist and have columns');

      final actualColumns = tableInfo.map((col) => col['name'] as String).toList();
      for (final col in expectedColumns) {
        expect(actualColumns.contains(col), isTrue, reason: 'Table $tableName should contain column $col');
      }
    }
  });

  test('Verify foreign key constraints prevent invalid inserts', () async {
    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;

    // Attempting to insert into fitness_profiles with non-existent user_id should fail due to foreign key constraint
    expect(
          () async => await db.insert('fitness_profiles', {
        'user_id': 9999,
        'full_name': 'Test User',
        'age': 30,
        'gender': 'Male',
        'height_cm': 180.0,
        'weight_kg': 75.0,
        'bmi': 23.1,
        'updated_at': '2026-01-01T00:00:00Z',
      }),
      throwsA(isA<DatabaseException>()),
    );
  });
}
