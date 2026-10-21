import 'package:flutter_test/flutter_test.dart';
import 'package:app_venture_flutter/features/fitness/data/seven_day_fitness_engine.dart';

void main() {
  group('Phase 8C Multi-CSV and ZIP Import Tests', () {
    test('1. Parse and merge multiple CSV strings correctly', () {
      const csv1 = 'date,heart points,move minutes,steps\n2026-10-01,20,30,7000\n2026-10-02,22,35,7500\n';
      const csv2 = 'date,heart points,move minutes,steps\n2026-10-03,25,40,8000\n2026-10-04,18,30,6800\n';

      final merged = SevenDayFitnessEngine.parseMultipleCsvs([csv1, csv2]);
      expect(merged.length, 4);
      expect(merged.any((r) => r.dateKey == '2026-10-01'), true);
      expect(merged.any((r) => r.dateKey == '2026-10-03'), true);
    });

    test('2. ZIP archive signature detection works correctly', () {
      // ZIP magic bytes: PK\x03\x04
      final validZipBytes = [0x50, 0x4B, 0x03, 0x04, 0x00, 0x00];
      final invalidBytes = [0x00, 0x01, 0x02, 0x03];

      expect(SevenDayFitnessEngine.isZipArchive(validZipBytes), true);
      expect(SevenDayFitnessEngine.isZipArchive(invalidBytes), false);
    });
  });
}
