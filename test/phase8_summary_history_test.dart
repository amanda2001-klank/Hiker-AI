import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_venture_flutter/core/database/database_helper.dart';
import 'package:app_venture_flutter/features/hiking/data/hiking_session_repository.dart';
import 'package:app_venture_flutter/features/fitness/data/fitness_profile_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    DatabaseHelper.customDbPath = 'test_phase8_${DateTime.now().microsecondsSinceEpoch}.db';
  });

  tearDown(() async {
    try {
      await DatabaseHelper.instance.close();
    } catch (_) {}
  });

  test('Session Finalization and Hiking History Persistence Test', () async {
    final dbHelper = DatabaseHelper.instance;
    final profileRepo = FitnessProfileRepository(dbHelper);
    final sessionRepo = HikingSessionRepository(dbHelper);

    final userId = await profileRepo.getOrCreateUserIdByEmail('summary_user@venture.com', 'Summary User');

    // Start session
    final sessionId = await sessionRepo.startHikeSession(userId: userId, trailId: null);
    expect(sessionId, isNotNull);

    // End / finalize session
    await sessionRepo.endHikeSession(sessionId, totalDistance: 10.2, calories: 850.0);

    // Verify session summary retrieval
    final summary = await sessionRepo.getSessionSummary(sessionId);
    expect(summary, isNotNull);
    expect(summary!.totalDistanceKm, isNull);
    expect(summary.caloriesBurned, isNull);
    expect(summary.trailName, equals('Pine Mountain Trail'));

    // Verify hiking history entry
    final history = await sessionRepo.getHikingHistoryForUser(userId);
    expect(history.length, equals(1));
    expect(history.first['distance_km'], equals(10.2));
    expect(history.first['calories_burned'], equals(850.0));
  });

  test('User Data Isolation in Hiking History Test', () async {
    final dbHelper = DatabaseHelper.instance;
    final profileRepo = FitnessProfileRepository(dbHelper);
    final sessionRepo = HikingSessionRepository(dbHelper);

    final user1Id = await profileRepo.getOrCreateUserIdByEmail('user1@venture.com', 'User One');
    final user2Id = await profileRepo.getOrCreateUserIdByEmail('user2@venture.com', 'User Two');

    final session1 = await sessionRepo.startHikeSession(userId: user1Id);
    await sessionRepo.endHikeSession(session1, totalDistance: 5.0, calories: 400.0);

    final history1 = await sessionRepo.getHikingHistoryForUser(user1Id);
    final history2 = await sessionRepo.getHikingHistoryForUser(user2Id);

    expect(history1.length, equals(1));
    expect(history2.isEmpty, isTrue);
  });
}
