import 'package:sqflite/sqflite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_helper.dart';
import 'session_telemetry_repository.dart';

class SessionSummaryModel {
  final int sessionId;
  final int userId;
  final String trailName;
  final String hikingDate;
  final String startTime;
  final String endTime;
  final String totalDuration;
  final double? totalDistanceKm;
  final int? steps;
  final double? caloriesBurned;
  final double? avgHeartRate;
  final double? maxHeartRate;
  final double? elevationGainM;
  final double? avgBorg;
  final double? maxBorg;
  final int hrObservations;
  final int borgObservations;
  final String dataSource;
  final bool isDemo;

  SessionSummaryModel({
    required this.sessionId,
    required this.userId,
    required this.trailName,
    required this.hikingDate,
    required this.startTime,
    required this.endTime,
    required this.totalDuration,
    required this.totalDistanceKm,
    required this.steps,
    required this.caloriesBurned,
    this.avgHeartRate,
    this.maxHeartRate,
    this.elevationGainM,
    this.avgBorg,
    this.maxBorg,
    this.hrObservations = 0,
    this.borgObservations = 0,
    required this.dataSource,
    required this.isDemo,
  });

  factory SessionSummaryModel.fromMap(
    Map<String, dynamic> sessionMap,
    Map<String, dynamic>? trailMap,
    Map<String, dynamic>? historyMap,
    Map<String, dynamic>? metrics,
  ) {
    final start =
        DateTime.tryParse(sessionMap['start_time']?.toString() ?? '') ??
        DateTime.now();
    final end =
        DateTime.tryParse(sessionMap['end_time']?.toString() ?? '') ??
        DateTime.now();
    final duration = end.difference(start);
    final durationStr =
        '${duration.inHours}h ${duration.inMinutes % 60}m ${duration.inSeconds % 60}s';

    final hrCount = (metrics?['hr_count'] as num?)?.toInt() ?? 0;
    final borgCount = (metrics?['borg_count'] as num?)?.toInt() ?? 0;
    final eleMin = (metrics?['elevation_min'] as num?)?.toDouble();
    final hasWatch =
        metrics != null &&
        (hrCount > 0 ||
            metrics['step_last'] != null ||
            metrics['distance_max'] != null ||
            eleMin != null ||
            ((metrics['elevation_samples'] as num?)?.toInt() ?? 0) > 0);
    return SessionSummaryModel(
      sessionId: sessionMap['id'] as int? ?? 0,
      userId: sessionMap['user_id'] as int? ?? 0,
      trailName:
          trailMap?['name'] as String? ??
          historyMap?['trail_name'] as String? ??
          'Unknown trail',
      hikingDate: start.toIso8601String().substring(0, 10),
      startTime: start.toIso8601String(),
      endTime: end.toIso8601String(),
      totalDuration: durationStr,
      // Legacy fallback values were never verified: don't reuse them.
      totalDistanceKm: (metrics?['distance_max'] as num?)?.toDouble(),
      steps: metrics?['step_last'] == null
          ? null
          : (metrics?['step_delta'] as num?)?.toInt(),
      caloriesBurned: (metrics?['calories_max'] as num?)?.toDouble(),
      avgHeartRate: hrCount > 0
          ? (metrics!['hr_sum'] as num).toDouble() / hrCount
          : null,
      maxHeartRate: hrCount > 0
          ? (metrics!['hr_max'] as num?)?.toDouble()
          : null,
      elevationGainM:
          ((metrics?['elevation_samples'] as num?)?.toInt() ?? 0) >= 2
          ? (metrics?['elevation_gain'] as num?)?.toDouble()
          : null,
      avgBorg: borgCount > 0
          ? (metrics!['borg_sum'] as num).toDouble() / borgCount
          : null,
      maxBorg: borgCount > 0
          ? (metrics!['borg_max'] as num?)?.toDouble()
          : null,
      hrObservations: hrCount,
      borgObservations: borgCount,
      dataSource: hasWatch
          ? 'Watch6 / phone GPS observations (partial coverage possible)'
          : 'No verified Watch6 measurements',
      isDemo: false,
    );
  }
}

class HikingSessionModel {
  final int? id;
  final int userId;
  final int? trailId;
  final String startTime;
  final String? endTime;
  final String status;
  final double? currentHeartRate;
  final double? distanceCoveredKm;
  final double? caloriesBurned;

  HikingSessionModel({
    this.id,
    required this.userId,
    this.trailId,
    required this.startTime,
    this.endTime,
    required this.status,
    this.currentHeartRate,
    this.distanceCoveredKm,
    this.caloriesBurned,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'trail_id': trailId,
      'start_time': startTime,
      'end_time': endTime,
      'status': status,
      'current_heart_rate': currentHeartRate,
      'distance_covered_km': distanceCoveredKm,
      'calories_burned': caloriesBurned,
    };
  }

  factory HikingSessionModel.fromMap(Map<String, dynamic> map) {
    return HikingSessionModel(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      trailId: map['trail_id'] as int?,
      startTime: map['start_time'] as String,
      endTime: map['end_time'] as String?,
      status: map['status'] as String? ?? 'active',
      currentHeartRate: map['current_heart_rate'] != null
          ? (map['current_heart_rate'] as num).toDouble()
          : null,
      distanceCoveredKm: map['distance_covered_km'] != null
          ? (map['distance_covered_km'] as num).toDouble()
          : null,
      caloriesBurned: map['calories_burned'] != null
          ? (map['calories_burned'] as num).toDouble()
          : null,
    );
  }
}

class HikingSessionRepository {
  final DatabaseHelper databaseHelper;

  HikingSessionRepository(this.databaseHelper);

  Future<int> startHikeSession({required int userId, int? trailId}) async {
    final db = await databaseHelper.database;

    final activeSessions = await db.query(
      'hiking_sessions',
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, 'active'],
    );

    if (activeSessions.isNotEmpty) {
      return activeSessions.first['id'] as int;
    }

    final session = HikingSessionModel(
      userId: userId,
      trailId: trailId,
      startTime: DateTime.now().toIso8601String(),
      status: 'active',
    );

    return await db.insert(
      'hiking_sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<HikingSessionModel?> getActiveSession(int userId) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      'hiking_sessions',
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, 'active'],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      return HikingSessionModel.fromMap(rows.first);
    }
    return null;
  }

  Future<void> endHikeSession(
    int sessionId, {
    double? totalDistance,
    double? calories,
  }) async {
    final db = await databaseHelper.database;

    await db.transaction((txn) async {
      // Check if already completed to prevent duplicate finalization
      final sessionRow = await txn.query(
        'hiking_sessions',
        where: 'id = ?',
        whereArgs: [sessionId],
        limit: 1,
      );
      if (sessionRow.isEmpty) return;
      if (sessionRow.first['status'] == 'completed') return;

      final endTimeStr = DateTime.now().toIso8601String();
      final startTimeStr =
          sessionRow.first['start_time'] as String? ?? endTimeStr;
      final userId = sessionRow.first['user_id'] as int;
      final trailId = sessionRow.first['trail_id'] as int?;

      // Update hiking session
      await txn.update(
        'hiking_sessions',
        {
          'status': 'completed',
          'end_time': endTimeStr,
          'distance_covered_km': totalDistance,
          'calories_burned': calories,
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      // Get trail name if available
      String trailName = 'Pine Mountain Trail';
      if (trailId != null) {
        final trailRow = await txn.query(
          'trails',
          where: 'id = ?',
          whereArgs: [trailId],
          limit: 1,
        );
        if (trailRow.isNotEmpty) {
          trailName = trailRow.first['name'] as String? ?? trailName;
        }
      }

      final startDt = DateTime.tryParse(startTimeStr) ?? DateTime.now();
      final endDt = DateTime.tryParse(endTimeStr) ?? DateTime.now();
      final durationMins = endDt.difference(startDt).inMinutes;

      // Insert into hiking_history (Requirement 4)
      await txn.insert('hiking_history', {
        'user_id': userId,
        'hiking_session_id': sessionId,
        'trail_name': trailName,
        'hiking_date': startDt.toIso8601String().substring(0, 10),
        'distance_km': totalDistance,
        'duration_minutes': durationMins > 0 ? durationMins : 1,
        'calories_burned': calories,
        'status': 'completed',
        'completed_at': endTimeStr,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<SessionSummaryModel?> getSessionSummary(int sessionId) async {
    final db = await databaseHelper.database;
    final sessionRows = await db.query(
      'hiking_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (sessionRows.isEmpty) return null;

    final sessionMap = sessionRows.first;
    final trailId = sessionMap['trail_id'] as int?;
    Map<String, dynamic>? trailMap;
    if (trailId != null) {
      final trailRows = await db.query(
        'trails',
        where: 'id = ?',
        whereArgs: [trailId],
        limit: 1,
      );
      if (trailRows.isNotEmpty) trailMap = trailRows.first;
    }

    final historyRows = await db.query(
      'hiking_history',
      where: 'hiking_session_id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    final historyMap = historyRows.isNotEmpty ? historyRows.first : null;

    final metrics = await SessionTelemetryRepository(databaseHelper)
        .getMetrics(sessionId);
    return SessionSummaryModel.fromMap(
      sessionMap,
      trailMap,
      historyMap,
      metrics,
    );
  }

  Future<List<Map<String, dynamic>>> getHikingHistoryForUser(int userId) async {
    final db = await databaseHelper.database;
    return await db.query(
      'hiking_history',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'completed_at DESC',
    );
  }
}

final hikingSessionRepositoryProvider = Provider<HikingSessionRepository>((
  ref,
) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return HikingSessionRepository(dbHelper);
});
