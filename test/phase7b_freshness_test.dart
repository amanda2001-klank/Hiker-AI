import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 7B Assessment Freshness Policy Tests', () {
    bool isAssessmentFresh(String endDateStr) {
      final endDate = DateTime.tryParse(endDateStr);
      if (endDate == null) return false;
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final normalizedEndDate = DateTime(endDate.year, endDate.month, endDate.day);
      final diffDays = todayDate.difference(normalizedEndDate).inDays;
      return diffDays >= 0 && diffDays <= 7;
    }

    test('1. Assessment ending today is fresh', () {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      expect(isAssessmentFresh(todayStr), true);
    });

    test('2. Assessment ending 7 days ago is fresh', () {
      final dateStr = DateTime.now().subtract(const Duration(days: 7)).toIso8601String().substring(0, 10);
      expect(isAssessmentFresh(dateStr), true);
    });

    test('3. Assessment ending 8 days ago is stale', () {
      final dateStr = DateTime.now().subtract(const Duration(days: 8)).toIso8601String().substring(0, 10);
      expect(isAssessmentFresh(dateStr), false);
    });

    test('4. Assessment ending 30 days ago is stale', () {
      final dateStr = DateTime.now().subtract(const Duration(days: 30)).toIso8601String().substring(0, 10);
      expect(isAssessmentFresh(dateStr), false);
    });

    test('5. Future-dated assessment is invalid', () {
      final futureStr = DateTime.now().add(const Duration(days: 3)).toIso8601String().substring(0, 10);
      expect(isAssessmentFresh(futureStr), false);
    });

    test('6. Invalid date format is rejected', () {
      expect(isAssessmentFresh('not-a-date'), false);
    });
  });
}
