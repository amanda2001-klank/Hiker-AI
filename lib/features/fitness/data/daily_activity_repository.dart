import 'package:sqflite/sqflite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';

class DailyActivityModel {
  final int? id;
  final int userId;
  final String date; // YYYY-MM-DD
  final int steps;
  final double caloriesBurned;
  final double distanceKm;
  final double avgHeartRate;

  DailyActivityModel({
    this.id,
    required this.userId,
    required this.date,
    required this.steps,
    required this.caloriesBurned,
    required this.distanceKm,
    required this.avgHeartRate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'date': date,
      'steps': steps,
      'calories_burned': caloriesBurned,
      'distance_km': distanceKm,
      'avg_heart_rate': avgHeartRate,
    };
  }

  factory DailyActivityModel.fromMap(Map<String, dynamic> map) {
    return DailyActivityModel(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      date: map['date'] as String,
      steps: map['steps'] as int,
      caloriesBurned: (map['calories_burned'] as num).toDouble(),
      distanceKm: (map['distance_km'] as num).toDouble(),
      avgHeartRate: (map['avg_heart_rate'] as num).toDouble(),
    );
  }

  // Documented definition: Calories burned = steps * 0.04 kcal + distance_km * 60.0
  static double calculateCalories(int steps, double distanceKm) {
    return (steps * 0.04) + (distanceKm * 50.0);
  }
}

class DailyActivityRepository {
  final DatabaseHelper databaseHelper;

  DailyActivityRepository(this.databaseHelper);

  Future<void> upsertDailyActivity(DailyActivityModel activity) async {
    final db = await databaseHelper.database;
    final existing = await db.query(
      'daily_activities',
      where: 'user_id = ? AND date = ?',
      whereArgs: [activity.userId, activity.date],
    );

    if (existing.isNotEmpty) {
      await db.update(
        'daily_activities',
        activity.toMap(),
        where: 'user_id = ? AND date = ?',
        whereArgs: [activity.userId, activity.date],
      );
    } else {
      await db.insert('daily_activities', activity.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<DailyActivityModel?> getLatestActivityForUser(int userId) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      'daily_activities',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'date DESC',
      limit: 1,
    );

    if (rows.isNotEmpty) {
      return DailyActivityModel.fromMap(rows.first);
    }
    return null;
  }
}

final dailyActivityRepositoryProvider = Provider<DailyActivityRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return DailyActivityRepository(dbHelper);
});
