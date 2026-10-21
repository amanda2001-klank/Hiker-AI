import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_venture_flutter/core/database/database_helper.dart';
import 'package:app_venture_flutter/core/api/api_client.dart';
import 'package:app_venture_flutter/features/fitness/data/experience_assessment_repository.dart';
import 'package:app_venture_flutter/features/fitness/data/fitness_profile_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    DatabaseHelper.customDbPath = 'test_phase4_${DateTime.now().microsecondsSinceEpoch}.db';
  });

  tearDown(() async {
    try {
      await DatabaseHelper.instance.close();
    } catch (_) {}
  });

  test('Experience Scoring and Classification Boundaries Test', () {
    // Beginner: 4 - 7
    expect(ExperienceAssessmentModel.calculateLevel(4), equals('Beginner'));
    expect(ExperienceAssessmentModel.calculateLevel(7), equals('Beginner'));

    // Intermediate: 8 - 11
    expect(ExperienceAssessmentModel.calculateLevel(8), equals('Intermediate'));
    expect(ExperienceAssessmentModel.calculateLevel(11), equals('Intermediate'));

    // Advanced: 12 - 16
    expect(ExperienceAssessmentModel.calculateLevel(12), equals('Advanced'));
    expect(ExperienceAssessmentModel.calculateLevel(16), equals('Advanced'));
  });

  test('Survey Question Parsing Test', () {
    final json = {
      'code': 'Q01',
      'title': 'How many years of experience?',
      'hint': 'Be honest',
      'answers': ['< 1', '1-3', '3-5', '5+'],
    };

    final question = SurveyQuestion.fromJson(json);
    expect(question.code, equals('Q01'));
    expect(question.title, equals('How many years of experience?'));
    expect(question.hint, equals('Be honest'));
    expect(question.answers.length, equals(4));
    expect(question.answers[0], equals('< 1'));
  });

  test('SQLite Experience Assessment Persistence and User Isolation Test', () async {
    final dbHelper = DatabaseHelper.instance;
    final profileRepo = FitnessProfileRepository(dbHelper);
    final assessmentRepo = ExperienceAssessmentRepository(
      ApiClient(),
      dbHelper,
    );

    final user1Id = await profileRepo.getOrCreateUserIdByEmail('user1@venture.com', 'User One');
    final user2Id = await profileRepo.getOrCreateUserIdByEmail('user2@venture.com', 'User Two');

    // Save assessment for user 1
    final assessment1 = ExperienceAssessmentModel(
      userId: user1Id,
      q1Answer: '1 - 3 years',
      q2Answer: 'Hilly / Rolling Hills',
      q3Answer: '5 - 10 km',
      q4Answer: '1-2 times a week',
      calculatedScore: 10.0,
      experienceLevel: ExperienceAssessmentModel.calculateLevel(10),
      assessedAt: DateTime.now().toIso8601String(),
    );

    await assessmentRepo.saveAssessmentToDb(assessment1);

    // Retrieve latest assessment for user 1
    final retrieved1 = await assessmentRepo.getLatestAssessmentForUser(user1Id);
    expect(retrieved1, isNotNull);
    expect(retrieved1!.experienceLevel, equals('Intermediate'));
    expect(retrieved1.calculatedScore, equals(10.0));

    // Retrieve for user 2 (should be null)
    final retrieved2 = await assessmentRepo.getLatestAssessmentForUser(user2Id);
    expect(retrieved2, isNull);
  });
}
