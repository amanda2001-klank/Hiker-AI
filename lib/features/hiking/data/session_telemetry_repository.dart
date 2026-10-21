import 'package:sqflite/sqflite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_helper.dart';
import 'sensor_data_model.dart';

/// Session-scoped observations. Values here are non-diagnostic and originate
/// only from non-simulated fresh Watch6 telemetry or completed ONNX inference.
class SessionTelemetryRepository {
  final DatabaseHelper helper;
  SessionTelemetryRepository(this.helper);

  Future<void> _prepare() async {
    final db = await helper.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS hike_observed_metrics (
        session_id INTEGER PRIMARY KEY,
        hr_sum REAL NOT NULL DEFAULT 0,
        hr_count INTEGER NOT NULL DEFAULT 0,
        hr_max REAL,
        step_last INTEGER,
        step_delta INTEGER NOT NULL DEFAULT 0,
        distance_max REAL,
        calories_max REAL,
        elevation_min REAL,
        elevation_max REAL,
        elevation_gain REAL NOT NULL DEFAULT 0,
        elevation_last REAL,
        elevation_samples INTEGER NOT NULL DEFAULT 0,
        borg_sum REAL NOT NULL DEFAULT 0,
        borg_count INTEGER NOT NULL DEFAULT 0,
        borg_max REAL,
        FOREIGN KEY(session_id) REFERENCES hiking_sessions(id) ON DELETE CASCADE
      )
    ''');
    final columns = await db.rawQuery(
      'PRAGMA table_info(hike_observed_metrics)',
    );
    if (!columns.any((c) => c['name'] == 'elevation_gain')) {
      await db.execute(
        'ALTER TABLE hike_observed_metrics ADD COLUMN elevation_gain REAL NOT NULL DEFAULT 0',
      );
    }
    if (!columns.any((c) => c['name'] == 'elevation_last')) {
      await db.execute(
        'ALTER TABLE hike_observed_metrics ADD COLUMN elevation_last REAL',
      );
    }
    if (!columns.any((c) => c['name'] == 'elevation_samples')) {
      await db.execute(
        'ALTER TABLE hike_observed_metrics ADD COLUMN elevation_samples INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (!columns.any((c) => c['name'] == 'calories_max')) {
      await db.execute(
        'ALTER TABLE hike_observed_metrics ADD COLUMN calories_max REAL',
      );
    }
  }

  Future<void> recordReading(int sessionId, SensorDataModel reading) async {
    if (sessionId <= 0 ||
        !reading.dataSource.startsWith('Watch6 telemetry') ||
        reading.measurementQuality == 'simulated') {
      return;
    }
    final age = DateTime.now().difference(reading.timestamp);
    if (age.isNegative ||
        age > const Duration(seconds: 10) ||
        reading.dataFreshness > const Duration(seconds: 10)) {
      return;
    }
    final hr = reading.heartRate;
    final steps = reading.stepCount;
    final distance = reading.distanceKm;
    final calories = reading.caloriesBurned;
    final elev = reading.elevationM;
    if (hr == null &&
        steps == null &&
        distance == null &&
        elev == null &&
        calories == null) {
      return;
    }

    await _prepare();
    final db = await helper.database;
    await db.transaction((txn) async {
      await txn.insert('hike_observed_metrics', {
        'session_id': sessionId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final rows = await txn.query(
        'hike_observed_metrics',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final prev = rows.first;
      final updates = <String, Object?>{};
      if (hr != null && hr.isFinite && hr >= 30 && hr <= 220) {
        updates['hr_sum'] = (prev['hr_sum'] as num).toDouble() + hr;
        updates['hr_count'] = (prev['hr_count'] as num).toInt() + 1;
        final oldMax = (prev['hr_max'] as num?)?.toDouble();
        updates['hr_max'] = oldMax == null || hr > oldMax ? hr : oldMax;
      }
      if (steps != null && steps >= 0) {
        final last = (prev['step_last'] as num?)?.toInt();
        // The first counter sample is a baseline, NOT hike steps.
        // A counter reset is treated as a new baseline, not an increment.
        if (last != null && steps >= last) {
          updates['step_delta'] =
              (prev['step_delta'] as num).toInt() + steps - last;
        }
        updates['step_last'] = steps;
      }
      if (distance != null && distance.isFinite && distance >= 0) {
        final old = (prev['distance_max'] as num?)?.toDouble();
        updates['distance_max'] = old == null || distance > old
            ? distance
            : old;
      }
      // Watch6 CALORIES_TOTAL is cumulative; never sum repeated packets.
      // This is a last-reported exercise total, not guaranteed fresh on every packet.
      if (calories != null && calories.isFinite && calories >= 0) {
        final oldCalories = (prev['calories_max'] as num?)?.toDouble();
        updates['calories_max'] = oldCalories == null || calories > oldCalories
            ? calories
            : oldCalories;
      }
      if (elev != null && elev.isFinite) {
        final lo = (prev['elevation_min'] as num?)?.toDouble();
        final hi = (prev['elevation_max'] as num?)?.toDouble();
        updates['elevation_min'] = lo == null || elev < lo ? elev : lo;
        updates['elevation_max'] = hi == null || elev > hi ? elev : hi;
      }
      if (updates.isNotEmpty) {
        await txn.update(
          'hike_observed_metrics',
          updates,
          where: 'session_id = ?',
          whereArgs: [sessionId],
        );
      }
    });
  }

  /// Adds positive GPS altitude changes only. This is an approximation, not surveyed elevation.
  /// The first sample is a baseline. Small noise and implausible jumps are not counted.
  Future<void> recordPhoneElevation(int sessionId, double altitudeM) async {
    if (sessionId <= 0 ||
        !altitudeM.isFinite ||
        altitudeM < -500 ||
        altitudeM > 9000) {
      return;
    }
    await _prepare();
    final db = await helper.database;
    await db.transaction((txn) async {
      await txn.insert('hike_observed_metrics', {
        'session_id': sessionId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final prev = (await txn.query(
        'hike_observed_metrics',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        limit: 1,
      )).first;
      final last = (prev['elevation_last'] as num?)?.toDouble();
      final delta = last == null ? 0.0 : altitudeM - last;
      final gain = (prev['elevation_gain'] as num).toDouble();
      // More than 25m between accepted positions is likely a GPS altitude glitch;
      // do not count it, but use the new position as a baseline.
      final increment = delta >= 4.0 && delta <= 25.0 ? delta : 0.0;
      await txn.update(
        'hike_observed_metrics',
        {
          'elevation_last': altitudeM,
          'elevation_gain': gain + increment,
          'elevation_samples': (prev['elevation_samples'] as num).toInt() + 1,
        },
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
    });
  }

  Future<void> recordBorg(int sessionId, double score) async {
    if (sessionId <= 0 || !score.isFinite || score < 6 || score > 20) return;
    await _prepare();
    final db = await helper.database;
    await db.transaction((txn) async {
      await txn.insert('hike_observed_metrics', {
        'session_id': sessionId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final prev = (await txn.query(
        'hike_observed_metrics',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        limit: 1,
      )).first;
      final oldMax = (prev['borg_max'] as num?)?.toDouble();
      await txn.update(
        'hike_observed_metrics',
        {
          'borg_sum': (prev['borg_sum'] as num).toDouble() + score,
          'borg_count': (prev['borg_count'] as num).toInt() + 1,
          'borg_max': oldMax == null || score > oldMax ? score : oldMax,
        },
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
    });
  }

  Future<Map<String, dynamic>?> getMetrics(int sessionId) async {
    await _prepare();
    final rows = await (await helper.database).query(
      'hike_observed_metrics',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }
}

final sessionTelemetryRepositoryProvider = Provider<SessionTelemetryRepository>(
  (ref) => SessionTelemetryRepository(ref.watch(databaseHelperProvider)),
);
