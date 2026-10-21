import 'package:csv/csv.dart';
import 'package:archive/archive.dart';

class GoogleFitDailyActivity {
  final DateTime date;
  final double heartPoints;
  final double moveMinutes;
  final int stepCount;
  final bool isMissing;

  GoogleFitDailyActivity({
    required this.date,
    required this.heartPoints,
    required this.moveMinutes,
    required this.stepCount,
    this.isMissing = false,
  });

  String get dateKey => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class SevenDayFitnessAggregate {
  final List<GoogleFitDailyActivity> dailyActivities;
  final double hp7d;
  final double moveMin7d;
  final double stepsAvg7d;
  final int activeDays7d;
  final double componentA;
  final double componentB;
  final double componentC;
  final double componentE;
  final double finalActivityScore;
  final String formulaVersion;
  final String sourceProvenance;
  final List<String> dataQualityWarnings;

  SevenDayFitnessAggregate({
    required this.dailyActivities,
    required this.hp7d,
    required this.moveMin7d,
    required this.stepsAvg7d,
    required this.activeDays7d,
    required this.componentA,
    required this.componentB,
    required this.componentC,
    required this.componentE,
    required this.finalActivityScore,
    required this.formulaVersion,
    required this.sourceProvenance,
    required this.dataQualityWarnings,
  });

  bool get isComplete => dailyActivities.length >= 7 && dataQualityWarnings.isEmpty;
}

class SevenDayFitnessAssessmentRecord {
  final int? id;
  final int userId;
  final String assessmentStartDate;
  final String assessmentEndDate;
  final double calculatedScore;
  final double componentA;
  final double componentB;
  final double componentC;
  final double componentE;
  final String formulaVersion;
  final String dataSource;
  final String dataCompleteness;
  final String assessedAt;

  SevenDayFitnessAssessmentRecord({
    this.id,
    required this.userId,
    required this.assessmentStartDate,
    required this.assessmentEndDate,
    required this.calculatedScore,
    required this.componentA,
    required this.componentB,
    required this.componentC,
    required this.componentE,
    required this.formulaVersion,
    required this.dataSource,
    required this.dataCompleteness,
    required this.assessedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'assessment_start_date': assessmentStartDate,
      'assessment_end_date': assessmentEndDate,
      'calculated_score': calculatedScore,
      'component_a': componentA,
      'component_b': componentB,
      'component_c': componentC,
      'component_e': componentE,
      'formula_version': formulaVersion,
      'data_source': dataSource,
      'data_completeness': dataCompleteness,
      'assessed_at': assessedAt,
    };
  }

  factory SevenDayFitnessAssessmentRecord.fromMap(Map<String, dynamic> map) {
    return SevenDayFitnessAssessmentRecord(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      assessmentStartDate: map['assessment_start_date'] as String,
      assessmentEndDate: map['assessment_end_date'] as String,
      calculatedScore: (map['calculated_score'] as num).toDouble(),
      componentA: (map['component_a'] as num).toDouble(),
      componentB: (map['component_b'] as num).toDouble(),
      componentC: (map['component_c'] as num).toDouble(),
      componentE: (map['component_e'] as num).toDouble(),
      formulaVersion: map['formula_version'] as String,
      dataSource: map['data_source'] as String,
      dataCompleteness: map['data_completeness'] as String,
      assessedAt: map['assessed_at'] as String,
    );
  }
}

class SevenDayFitnessEngine {
  static const String formulaVersion = 'v1.0-google-fit-7d';

  static SevenDayFitnessAggregate calculate({
    required List<GoogleFitDailyActivity> activities,
    String sourceProvenance = 'Google Takeout / Multi-CSV',
  }) {
    final warnings = <String>[];
    if (activities.length < 7) {
      warnings.add('Fewer than 7 days of activity provided (${activities.length} days). Required: 7.');
    }

    // Sort by date ascending and take the latest 7 consecutive or available days
    activities.sort((a, b) => a.date.compareTo(b.date));
    final window7d = activities.length >= 7 ? activities.sublist(activities.length - 7) : activities;

    double hp7d = 0.0;
    double moveMin7d = 0.0;
    double totalSteps = 0.0;
    int activeDays7d = 0;

    for (final day in window7d) {
      if (day.isMissing) {
        warnings.add('Missing data detected for date: ${day.dateKey}.');
        continue;
      }
      hp7d += day.heartPoints;
      moveMin7d += day.moveMinutes;
      totalSteps += day.stepCount;
      if (day.moveMinutes >= 30.0) {
        activeDays7d++;
      }
    }

    final stepsAvg7d = window7d.isNotEmpty ? totalSteps / window7d.length : 0.0;

    // Approved research formula:
    // A = 25 * min(HP_7d / 150, 1)
    final a = 25.0 * (hp7d / 150.0 > 1.0 ? 1.0 : hp7d / 150.0);

    // B = 15 * min(Steps_avg_7d / 8000, 1)
    final b = 15.0 * (stepsAvg7d / 8000.0 > 1.0 ? 1.0 : stepsAvg7d / 8000.0);

    // C = 10 * min((HP_7d / MoveMin_7d) / 1.5, 1)
    double c = 0.0;
    if (moveMin7d > 0) {
      final ratio = (hp7d / moveMin7d) / 1.5;
      c = 10.0 * (ratio > 1.0 ? 1.0 : ratio);
    } else {
      warnings.add('Move Minutes sum is zero; Intensity Quality (C) component evaluated to 0.');
    }

    // E = 15 * min(ActiveDays_7d / 5, 1)
    final e = 15.0 * (activeDays7d / 5.0 > 1.0 ? 1.0 : activeDays7d / 5.0);

    // FinalActivityScore = ((A + B + C + E) / 65) * 100
    final sumComponents = a + b + c + e;
    final finalScore = ((sumComponents / 65.0) * 100.0).clamp(0.0, 100.0);

    return SevenDayFitnessAggregate(
      dailyActivities: window7d,
      hp7d: double.parse(hp7d.toStringAsFixed(1)),
      moveMin7d: double.parse(moveMin7d.toStringAsFixed(1)),
      stepsAvg7d: double.parse(stepsAvg7d.toStringAsFixed(1)),
      activeDays7d: activeDays7d,
      componentA: double.parse(a.toStringAsFixed(1)),
      componentB: double.parse(b.toStringAsFixed(1)),
      componentC: double.parse(c.toStringAsFixed(1)),
      componentE: double.parse(e.toStringAsFixed(1)),
      finalActivityScore: double.parse(finalScore.toStringAsFixed(1)),
      formulaVersion: formulaVersion,
      sourceProvenance: sourceProvenance,
      dataQualityWarnings: warnings,
    );
  }

  static bool isZipArchive(List<int> bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04;
  }

  // Safe Google Takeout ZIP extraction with path traversal and size limits
  static List<GoogleFitDailyActivity> parseZipBytes(List<int> zipBytes) {
    try {
      if (!isZipArchive(zipBytes)) {
        throw Exception('Invalid ZIP archive signature.');
      }

      final archive = ZipDecoder().decodeBytes(zipBytes);
      if (archive.files.length > 200) {
        throw Exception('Archive exceeds maximum allowed entry count (200).');
      }

      int totalDecompressedSize = 0;
      final mergedMap = <String, GoogleFitDailyActivity>{};
      final warnings = <String>[];

      for (final file in archive.files) {
        final filename = file.name;
        if (filename.contains('..') || filename.startsWith('/') || filename.contains('\\..')) {
          continue;
        }

        if (file.isFile && (filename.toLowerCase().endsWith('.csv') || filename.toLowerCase().contains('daily activity metrics'))) {
          final contentBytes = file.content as List<int>?;
          if (contentBytes == null) continue;

          totalDecompressedSize += contentBytes.length;
          if (totalDecompressedSize > 50 * 1024 * 1024) {
            throw Exception('Decompressed archive size exceeds 50MB limit.');
          }

          final csvString = String.fromCharCodes(contentBytes);
          final dailyRecords = parseCsv(csvString);

          for (final record in dailyRecords) {
            final key = record.dateKey;
            if (mergedMap.containsKey(key)) {
              final existing = mergedMap[key]!;
              if (existing.heartPoints == record.heartPoints &&
                  existing.moveMinutes == record.moveMinutes &&
                  existing.stepCount == record.stepCount) {
                continue;
              } else {
                warnings.add('Conflicting duplicate date detected for $key.');
                if (record.heartPoints + record.stepCount > existing.heartPoints + existing.stepCount) {
                  mergedMap[key] = record;
                }
              }
            } else {
              mergedMap[key] = record;
            }
          }
        }
      }

      return mergedMap.values.toList();
    } catch (e) {
      throw Exception('Safe ZIP extraction failed: $e');
    }
  }

  static List<GoogleFitDailyActivity> parseMultipleCsvs(List<String> csvStrings) {
    final mergedMap = <String, GoogleFitDailyActivity>{};

    for (final csv in csvStrings) {
      final records = parseCsv(csv);
      for (final record in records) {
        final key = record.dateKey;
        if (mergedMap.containsKey(key)) {
          final existing = mergedMap[key]!;
          if (existing.heartPoints == record.heartPoints &&
              existing.moveMinutes == record.moveMinutes &&
              existing.stepCount == record.stepCount) {
            continue;
          } else {
            if (record.heartPoints + record.stepCount > existing.heartPoints + existing.stepCount) {
              mergedMap[key] = record;
            }
          }
        } else {
          mergedMap[key] = record;
        }
      }
    }

    return mergedMap.values.toList();
  }

  static List<GoogleFitDailyActivity> parseCsv(String csvString) {
    var cleanCsv = csvString;
    if (cleanCsv.startsWith('\uFEFF')) {
      cleanCsv = cleanCsv.substring(1);
    }
    cleanCsv = cleanCsv.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rows = const CsvToListConverter(eol: '\n').convert(cleanCsv);
    if (rows.isEmpty) return [];

    final headers = rows.first.map((e) {
      var h = e.toString().trim().toLowerCase();
      h = h.replaceAll(RegExp(r'\s*\([^)]*\)$'), '');
      h = h.replaceAll(RegExp(r'\s+'), ' ');

      if (h == 'move minutes count') h = 'move minutes';
      if (h == 'heart points count') h = 'heart points';
      if (h == 'step count count') h = 'step count';

      return h;
    }).toList();

    int getColIndex(List<String> possibleNames) {
      for (final name in possibleNames) {
        final idx = headers.indexOf(name);
        if (idx != -1) return idx;
      }
      return -1;
    }

    final dateIdx = getColIndex(['date', 'timestamp', 'time', 'day']);
    final hpIdx = getColIndex(['heart points', 'heartpoints', 'hp']);
    final moveMinIdx = getColIndex(['move minutes', 'movemin', 'move_min', 'active minutes', 'active_minutes', 'duration']);
    final stepsIdx = getColIndex(['steps', 'step count', 'stepcount', 'step_count']);

    if (dateIdx == -1 || stepsIdx == -1) {
      return [];
    }

    final records = <GoogleFitDailyActivity>[];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      final dateStr = row[dateIdx].toString().trim();
      final date = DateTime.tryParse(dateStr);
      if (date == null) {
        continue;
      }

      double? parseNumOrNull(int idx) {
        if (idx == -1 || idx >= row.length) return null;
        final valStr = row[idx].toString().trim();
        if (valStr.isEmpty) return null;
        return double.tryParse(valStr);
      }

      final hp = parseNumOrNull(hpIdx) ?? 0.0;
      final moveMin = parseNumOrNull(moveMinIdx) ?? 0.0;
      final steps = parseNumOrNull(stepsIdx)?.toInt() ?? 0;

      final isMissing = hp < 0 || moveMin < 0 || steps < 0;

      records.add(GoogleFitDailyActivity(
        date: date,
        heartPoints: hp < 0 ? 0.0 : hp,
        moveMinutes: moveMin < 0 ? 0.0 : moveMin,
        stepCount: steps < 0 ? 0 : steps,
        isMissing: isMissing,
      ));
    }

    return records;
  }
}
