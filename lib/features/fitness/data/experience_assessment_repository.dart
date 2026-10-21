import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/api/api_client.dart';
import '../../../core/database/database_helper.dart';

class SurveyQuestion {
  final String code;
  final String title;
  final String? hint;
  final List<String> answers;

  SurveyQuestion({
    required this.code,
    required this.title,
    this.hint,
    required this.answers,
  });

  factory SurveyQuestion.fromJson(Map<String, dynamic> json) {
    var rawAnswers = json['answers'] ?? json['options'] ?? [];
    List<String> parsedAnswers = [];
    if (rawAnswers is List) {
      parsedAnswers = rawAnswers.map((e) => e.toString()).toList();
    }
    return SurveyQuestion(
      code: json['code'] as String? ?? 'Q01',
      title: json['title'] as String? ?? json['question'] as String? ?? '',
      hint: json['hint'] as String?,
      answers: parsedAnswers.isNotEmpty ? parsedAnswers : ['1', '2', '3', '4'],
    );
  }
}

class ExperienceAssessmentModel {
  final int? id;
  final int userId;
  final String q1Answer;
  final String q2Answer;
  final String q3Answer;
  final String q4Answer;
  final double calculatedScore;
  final String experienceLevel;
  final String assessedAt;

  ExperienceAssessmentModel({
    this.id,
    required this.userId,
    required this.q1Answer,
    required this.q2Answer,
    required this.q3Answer,
    required this.q4Answer,
    required this.calculatedScore,
    required this.experienceLevel,
    required this.assessedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'q1_answer': q1Answer,
      'q2_answer': q2Answer,
      'q3_answer': q3Answer,
      'q4_answer': q4Answer,
      'calculated_score': calculatedScore,
      'experience_level': experienceLevel,
      'assessed_at': assessedAt,
    };
  }

  factory ExperienceAssessmentModel.fromMap(Map<String, dynamic> map) {
    return ExperienceAssessmentModel(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      q1Answer: map['q1_answer'] as String,
      q2Answer: map['q2_answer'] as String,
      q3Answer: map['q3_answer'] as String,
      q4Answer: map['q4_answer'] as String,
      calculatedScore: (map['calculated_score'] as num).toDouble(),
      experienceLevel: map['experience_level'] as String,
      assessedAt: map['assessed_at'] as String,
    );
  }

  // Scoring logic: Each question scores 1-4. Total score range 4-16.
  // Beginner: 4-7, Intermediate: 8-11, Advanced: 12-16.
  static String calculateLevel(int totalScore) {
    if (totalScore <= 7) {
      return 'Beginner';
    } else if (totalScore <= 11) {
      return 'Intermediate';
    } else {
      return 'Advanced';
    }
  }
}

class ExperienceAssessmentRepository {
  final ApiClient apiClient;
  final DatabaseHelper databaseHelper;

  ExperienceAssessmentRepository(this.apiClient, this.databaseHelper);

  Future<List<SurveyQuestion>> getSurveyQuestions() async {
    try {
      final response = await apiClient.handleRequest(
            () => apiClient.dio.get('/survey'),
            (data) {
          if (data is List) {
            return data.map((e) => SurveyQuestion.fromJson(e is Map<String, dynamic> ? e : {})).toList();
          } else if (data is Map && data.containsKey('questions')) {
            final list = data['questions'] as List;
            return list.map((e) => SurveyQuestion.fromJson(e is Map<String, dynamic> ? e : {})).toList();
          }
          return <SurveyQuestion>[];
        },
      );
      if (response.data != null && response.data!.isNotEmpty) {
        return response.data!;
      }
    } on DioException {
      // Fallback to default questions if offline / network error
    }

    // Default verified 4 questions matching original specification
    return [
      SurveyQuestion(code: 'Q01', title: 'How many years of regular hiking experience do you have?', answers: ['< 1 year', '1 - 3 years', '3 - 5 years', '5+ years']),
      SurveyQuestion(code: 'Q02', title: 'What is your preferred hiking terrain?', answers: ['Flat Walking Paths', 'Hilly / Rolling Hills', 'Steep Mountain Trails', 'Rugged Backcountry']),
      SurveyQuestion(code: 'Q03', title: 'What is the maximum distance you comfortably hike in a day?', answers: ['Under 5 km', '5 - 10 km', '10 - 20 km', '20+ km']),
      SurveyQuestion(code: 'Q04', title: 'How often do you engage in strenuous cardio exercise?', answers: ['Rarely', '1-2 times a week', '3-4 times a week', 'Daily']),
    ];
  }

  Future<void> submitSurveyToApi(List<Map<String, String>> submissions) async {
    try {
      await apiClient.handleRequest(
            () => apiClient.dio.post('/survey', data: submissions),
            (data) => data,
      );
    } on DioException {
      rethrow;
    }
  }

  Future<void> saveAssessmentToDb(ExperienceAssessmentModel assessment) async {
    final db = await databaseHelper.database;
    await db.insert('experience_assessments', assessment.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<ExperienceAssessmentModel?> getLatestAssessmentForUser(int userId) async {
    final db = await databaseHelper.database;
    final result = await db.query(
      'experience_assessments',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'assessed_at DESC',
      limit: 1,
    );
    if (result.isNotEmpty) {
      return ExperienceAssessmentModel.fromMap(result.first);
    }
    return null;
  }
}

final experienceAssessmentRepositoryProvider = Provider<ExperienceAssessmentRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final dbHelper = ref.watch(databaseHelperProvider);
  return ExperienceAssessmentRepository(apiClient, dbHelper);
});
