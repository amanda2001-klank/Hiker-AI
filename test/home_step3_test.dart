import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_venture_flutter/core/database/database_helper.dart';
import 'package:app_venture_flutter/features/fitness/data/fitness_profile_repository.dart';
import 'package:app_venture_flutter/features/fitness/data/daily_activity_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    DatabaseHelper.customDbPath = 'test_home_step3_${DateTime.now().microsecondsSinceEpoch}.db';
  });

  tearDown(() async {
    try {
      await DatabaseHelper.instance.close();
    } catch (_) {}
  });

  test('Daily Activity Repository Upsert and Retrieval Test', () async {
    final dbHelper = DatabaseHelper.instance;
    final profileRepo = FitnessProfileRepository(dbHelper);
    final activityRepo = DailyActivityRepository(dbHelper);

    final userId = await profileRepo.getOrCreateLocalUserId(
      email: 'hiker@venture.com',
      username: 'HikerPro',
      backendUserId: 'uuid-hiker-123',
    );

    final today = '2026-10-14';
    final activity = DailyActivityModel(
      userId: userId,
      date: today,
      steps: 9500,
      caloriesBurned: DailyActivityModel.calculateCalories(9500, 6.2),
      distanceKm: 6.2,
      avgHeartRate: 132.5,
    );

    await activityRepo.upsertDailyActivity(activity);

    final latest = await activityRepo.getLatestActivityForUser(userId);
    expect(latest, isNotNull);
    expect(latest!.steps, equals(9500));
    expect(latest.distanceKm, equals(6.2));
    expect(latest.date, equals(today));
  });

  test('Daily Activity Cross-Account Data Isolation Test', () async {
    final dbHelper = DatabaseHelper.instance;
    final profileRepo = FitnessProfileRepository(dbHelper);
    final activityRepo = DailyActivityRepository(dbHelper);

    final user1 = await profileRepo.getOrCreateLocalUserId(email: 'user1@venture.com', username: 'User1', backendUserId: 'uuid-1');
    final user2 = await profileRepo.getOrCreateLocalUserId(email: 'user2@venture.com', username: 'User2', backendUserId: 'uuid-2');

    await activityRepo.upsertDailyActivity(DailyActivityModel(
      userId: user1,
      date: '2026-10-14',
      steps: 5000,
      caloriesBurned: 250.0,
      distanceKm: 3.5,
      avgHeartRate: 120.0,
    ));

    final act1 = await activityRepo.getLatestActivityForUser(user1);
    final act2 = await activityRepo.getLatestActivityForUser(user2);

    expect(act1, isNotNull);
    expect(act1!.steps, equals(5000));
    expect(act2, isNull); // User 2 has no activity data
  });
}
