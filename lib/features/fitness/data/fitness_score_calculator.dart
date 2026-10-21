import 'package:csv/csv.dart';
import 'math_utils.dart';

class FitnessScoreResult {
  final double totalScore;
  final String fitnessLevel;
  final double componentA; // Activity Volume (25)
  final double componentB; // Daily Movement (15)
  final double componentC; // Intensity Quality (10)
  final double componentD; // Cardiovascular (15)
  final double componentE; // Consistency (15)
  final double componentF; // BMI (10)
  final double componentG; // Gait & Mobility (10)
  final bool isComplete;
  final List<String> missingDataWarnings;

  FitnessScoreResult({
    required this.totalScore,
    required this.fitnessLevel,
    required this.componentA,
    required this.componentB,
    required this.componentC,
    required this.componentD,
    required this.componentE,
    required this.componentF,
    required this.componentG,
    required this.isComplete,
    required this.missingDataWarnings,
  });

  static String getLevel(double score) {
    if (score < 50) return 'Needs Improvement';
    if (score < 70) return 'Moderate';
    if (score < 85) return 'Good';
    return 'Excellent';
  }
}

class SmartwatchRecord {
  final DateTime timestamp;
  final double durationMins;
  final double moveMins;
  final double calories;
  final double distanceKm;
  final double heartPoints;
  final double avgHeartRate;
  final double maxHeartRate;
  final double minHeartRate;
  final double averageSpeedMs;
  final int stepCount;

  SmartwatchRecord({
    required this.timestamp,
    required this.durationMins,
    required this.moveMins,
    required this.calories,
    required this.distanceKm,
    required this.heartPoints,
    required this.avgHeartRate,
    required this.maxHeartRate,
    required this.minHeartRate,
    required this.averageSpeedMs,
    required this.stepCount,
  });
}

class FitnessScoreCalculator {
  static const String demoCsvContent = '''Timestamp,Duration,Move Min,Calories,Distance,Heart Points,Heart Min,Average HR,Max HR,Min HR,Average Speed,Max Speed,Min Speed,Step Count
2026-03-01T08:00:00Z,45,35,320,4.2,25,58,120,150,58,1.2,1.8,0.8,8500
2026-03-02T08:00:00Z,50,40,380,5.0,30,57,125,155,57,1.3,1.9,0.9,9200
2026-03-03T08:00:00Z,30,20,210,2.5,15,60,115,140,60,1.1,1.6,0.7,6100
2026-03-04T08:00:00Z,60,50,450,6.1,35,56,130,160,56,1.4,2.0,0.9,10500
2026-03-05T08:00:00Z,40,30,300,3.8,20,59,118,145,59,1.2,1.7,0.8,7800
2026-03-06T08:00:00Z,55,45,410,5.5,32,55,128,158,55,1.3,1.9,0.9,9800
2026-03-07T08:00:00Z,70,60,550,7.2,45,54,135,165,54,1.4,2.1,1.0,12000
2026-03-08T08:00:00Z,45,35,330,4.3,26,58,121,152,58,1.2,1.8,0.8,8600
2026-03-09T08:00:00Z,50,40,390,5.1,31,57,126,156,57,1.3,1.9,0.9,9300
2026-03-10T08:00:00Z,30,20,215,2.6,16,60,116,142,60,1.1,1.6,0.7,6200
2026-03-11T08:00:00Z,60,50,460,6.2,36,56,131,161,56,1.4,2.0,0.9,10600
2026-03-12T08:00:00Z,40,30,305,3.9,21,59,119,146,59,1.2,1.7,0.8,7900
2026-03-13T08:00:00Z,55,45,420,5.6,33,55,129,159,55,1.3,1.9,0.9,9900
2026-03-14T08:00:00Z,70,60,560,7.3,46,54,136,166,54,1.4,2.1,1.0,12100
2026-03-15T08:00:00Z,45,35,325,4.2,25,58,120,150,58,1.2,1.8,0.8,8550
2026-03-16T08:00:00Z,50,40,385,5.0,30,57,125,155,57,1.3,1.9,0.9,9250
2026-03-17T08:00:00Z,30,20,210,2.5,15,60,115,140,60,1.1,1.6,0.7,6150
2026-03-18T08:00:00Z,60,50,455,6.1,35,56,130,160,56,1.4,2.0,0.9,10550
2026-03-19T08:00:00Z,40,30,300,3.8,20,59,118,145,59,1.2,1.7,0.8,7850
2026-03-20T08:00:00Z,55,45,415,5.5,32,55,128,158,55,1.3,1.9,0.9,9850
2026-03-21T08:00:00Z,70,60,555,7.2,45,54,135,165,54,1.4,2.1,1.0,12050
2026-03-22T08:00:00Z,45,35,330,4.3,26,58,121,152,58,1.2,1.8,0.8,8650
2026-03-23T08:00:00Z,50,40,390,5.1,31,57,126,156,57,1.3,1.9,0.9,9350
2026-03-24T08:00:00Z,30,20,215,2.6,16,60,116,142,60,1.1,1.6,0.7,6250
2026-03-25T08:00:00Z,60,50,460,6.2,36,56,131,161,56,1.4,2.0,0.9,10650
2026-03-26T08:00:00Z,40,30,305,3.9,21,59,119,146,59,1.2,1.7,0.8,7950
2026-03-27T08:00:00Z,55,45,420,5.6,33,55,129,159,55,1.3,1.9,0.9,9950
2026-03-28T08:00:00Z,70,60,560,7.3,46,54,136,166,54,1.4,2.1,1.0,12150''';

  static List<SmartwatchRecord> parseCsv(String csvString) {
    final cleanCsv = csvString.replaceAll('\r\n', '\n');
    final rows = const CsvToListConverter(eol: '\n').convert(cleanCsv);
    if (rows.isEmpty) return [];

    final headers = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
    final records = <SmartwatchRecord>[];

    int getColIndex(List<String> possibleNames) {
      for (final name in possibleNames) {
        final idx = headers.indexOf(name);
        if (idx != -1) return idx;
      }
      return -1;
    }

    final tsIdx = getColIndex(['timestamp', 'date', 'time']);
    final durIdx = getColIndex(['duration', 'durationmins']);
    final moveIdx = getColIndex(['move min', 'movemin', 'move_min']);
    final calIdx = getColIndex(['calories', 'calories_burned']);
    final distIdx = getColIndex(['distance', 'distancekm']);
    final hpIdx = getColIndex(['heart points', 'heartpoints', 'hp']);
    final hrMinIdx = getColIndex(['heart min', 'min hr', 'minhr']);
    final hrAvgIdx = getColIndex(['average hr', 'avghr', 'average_hr']);
    final hrMaxIdx = getColIndex(['max hr', 'maxhr']);
    final speedAvgIdx = getColIndex(['average speed', 'avgspeed', 'speed']);
    final stepsIdx = getColIndex(['step count', 'steps', 'stepcount']);

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      try {
        final tsStr = tsIdx != -1 ? row[tsIdx].toString() : DateTime.now().toIso8601String();
        final timestamp = DateTime.tryParse(tsStr) ?? DateTime.now();

        double parseNum(int idx) {
          if (idx == -1 || idx >= row.length) return 0.0;
          return double.tryParse(row[idx].toString()) ?? 0.0;
        }

        records.add(SmartwatchRecord(
          timestamp: timestamp,
          durationMins: parseNum(durIdx),
          moveMins: parseNum(moveIdx),
          calories: parseNum(calIdx),
          distanceKm: parseNum(distIdx),
          heartPoints: parseNum(hpIdx),
          avgHeartRate: parseNum(hrAvgIdx),
          maxHeartRate: parseNum(hrMaxIdx),
          minHeartRate: hrMinIdx != -1 ? parseNum(hrMinIdx) : (parseNum(hrAvgIdx) > 0 ? parseNum(hrAvgIdx) - 20 : 60.0),
          averageSpeedMs: parseNum(speedAvgIdx),
          stepCount: parseNum(stepsIdx).toInt(),
        ));
      } catch (_) {}
    }

    return records;
  }

  static FitnessScoreResult calculate({
    required List<SmartwatchRecord> records,
    required double heightCm,
    required double weightKg,
  }) {
    final warnings = <String>[];
    if (records.isEmpty) {
      return FitnessScoreResult(
        totalScore: 0,
        fitnessLevel: 'Insufficient Data',
        componentA: 0, componentB: 0, componentC: 0, componentD: 0, componentE: 0, componentF: 0, componentG: 0,
        isComplete: false,
        missingDataWarnings: ['No records found in CSV dataset.'],
      );
    }

    // Sort by timestamp
    records.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final now = records.last.timestamp;
    final cutoff7d = now.subtract(const Duration(days: 7));
    final cutoff28d = now.subtract(const Duration(days: 28));

    final records7d = records.where((r) => r.timestamp.isAfter(cutoff7d)).toList();
    final records28d = records.where((r) => r.timestamp.isAfter(cutoff28d)).toList();

    if (records28d.length < 7) {
      warnings.pushUnique('Dataset has fewer than 7 days of timestamped data. Scores may be unrepresentative.');
    }

    // A. Activity Volume (max 25): A = 25 * min(HP_7d / 150, 1)
    double hp7d = records7d.fold(0.0, (sum, r) => sum + r.heartPoints);
    if (records7d.isEmpty) hp7d = records.take(7).fold(0.0, (sum, r) => sum + r.heartPoints);
    final componentA = 25.0 * MathUtils.clamp(hp7d / 150.0, 0, 1);

    // B. Daily Movement (max 15): B = 15 * min(Steps_avg_7d / 8000, 1)
    double steps7dSum = records7d.fold(0.0, (sum, r) => sum + r.stepCount);
    double stepsAvg7d = records7d.isNotEmpty ? steps7dSum / records7d.length : 0.0;
    final componentB = 15.0 * MathUtils.clamp(stepsAvg7d / 8000.0, 0, 1);

    // C. Intensity Quality (max 10): C = 10 * min((HP_7d / MoveMin_7d) / 1.5, 1)
    double moveMin7d = records7d.fold(0.0, (sum, r) => sum + r.moveMins);
    double componentC = 0.0;
    if (moveMin7d > 0) {
      final intensityRatio = (hp7d / moveMin7d) / 1.5;
      componentC = 10.0 * MathUtils.clamp(intensityRatio, 0, 1);
    } else {
      warnings.pushUnique('Move Minutes unavailable for 7-day window; Intensity Quality component unavailable.');
    }

    // D. Cardiovascular (max 15): D = 15 * clamp((100 - RHR_proxy) / 50, 0, 1)
    // RHR_proxy is 5th percentile of daily minimum heart-rate values over 28 days
    final minHrs = (records28d.isNotEmpty ? records28d : records).map((r) => r.minHeartRate).toList();
    minHrs.sort();
    double rhrProxy = 70.0;
    if (minHrs.isNotEmpty) {
      final p5Idx = (minHrs.length * 0.05).floor();
      rhrProxy = minHrs[p5Idx.clamp(0, minHrs.length - 1)];
    }
    final componentD = 15.0 * MathUtils.clamp((100.0 - rhrProxy) / 50.0, 0, 1);

    // E. Consistency (max 15): E = 15 * min(active_days_7d / 5, 1) (active day has >= 30 Move Minutes)
    // Group 7d records by day
    final Map<String, double> dailyMoveMins = {};
    for (final r in records7d) {
      final dayKey = '${r.timestamp.year}-${r.timestamp.month}-${r.timestamp.day}';
      dailyMoveMins[dayKey] = (dailyMoveMins[dayKey] ?? 0.0) + r.moveMins;
    }
    int activeDays7d = dailyMoveMins.values.where((m) => m >= 30.0).length;
    final componentE = 15.0 * MathUtils.clamp(activeDays7d / 5.0, 0, 1);

    // F. BMI (max 10): Authoritative research range 18.5 - 24.9
    double bmi = 22.0;
    if (heightCm > 0 && weightKg > 0) {
      final heightM = heightCm / 100.0;
      bmi = weightKg / (heightM * heightM);
    }
    double componentF = 10.0;
    if (bmi < 18.5) {
      final diff = 18.5 - bmi;
      componentF = 10.0 * MathUtils.max(0, 1.0 - diff / 7.0);
    } else if (bmi > 24.9) {
      final diff = bmi - 24.9;
      componentF = 10.0 * MathUtils.max(0, 1.0 - diff / 7.0);
    }

    // G. Gait and Mobility (max 10): G = 10 * clamp((speed_m_s - 0.6) / (1.3 - 0.6), 0, 1)
    double avgSpeedMs = records7d.isNotEmpty
        ? records7d.fold(0.0, (sum, r) => sum + r.averageSpeedMs) / records7d.length
        : 1.1;
    final componentG = 10.0 * MathUtils.clamp((avgSpeedMs - 0.6) / (1.3 - 0.6), 0, 1);

    final totalScore = componentA + componentB + componentC + componentD + componentE + componentF + componentG;
    final clampedTotal = totalScore.clamp(0.0, 100.0);
    final fitnessLevel = FitnessScoreResult.getLevel(clampedTotal);

    return FitnessScoreResult(
      totalScore: double.parse(clampedTotal.toStringAsFixed(1)),
      fitnessLevel: fitnessLevel,
      componentA: double.parse(componentA.toStringAsFixed(1)),
      componentB: double.parse(componentB.toStringAsFixed(1)),
      componentC: double.parse(componentC.toStringAsFixed(1)),
      componentD: double.parse(componentD.toStringAsFixed(1)),
      componentE: double.parse(componentE.toStringAsFixed(1)),
      componentF: double.parse(componentF.toStringAsFixed(1)),
      componentG: double.parse(componentG.toStringAsFixed(1)),
      isComplete: warnings.isEmpty,
      missingDataWarnings: warnings,
    );
  }
}

extension ListExtensions on List<String> {
  void pushUnique(String item) {
    if (!contains(item)) add(item);
  }
}
