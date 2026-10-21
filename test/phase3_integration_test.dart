import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_venture_flutter/core/database/database_helper.dart';
import 'package:app_venture_flutter/features/fitness/data/fitness_profile_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    DatabaseHelper.customDbPath = 'test_phase3_${DateTime.now().microsecondsSinceEpoch}.db';
  });

  tearDown(() async {
    try {
      await DatabaseHelper.instance.close();
    } catch (_) {}
  });

  test('BMI Calculation Test', () {
    final bmi = FitnessProfileModel.calculateBmi(70.0, 175.0);
    // 70 / (1.75^2) = 70 / 3.0625 = 22.857...
    expect(bmi, closeTo(22.86, 0.1));

    final zeroBmi = FitnessProfileModel.calculateBmi(70.0, 0.0);
    expect(zeroBmi, equals(0.0));
  });

  test('SQLite Profile Insert and Retrieval Test', () async {
    final dbHelper = DatabaseHelper.instance;
    final profileRepo = FitnessProfileRepository(dbHelper);

    // 1. Get or create user id
    final userId = await profileRepo.getOrCreateUserIdByEmail('testuser@venture.com', 'Test User');
    expect(userId, isNotNull);

    // 2. Save profile
    final profile = FitnessProfileModel(
      userId: userId,
      fullName: 'Test User Full',
      age: 30,
      gender: 'Non-Binary',
      heightCm: 180.0,
      weightKg: 80.0,
      bmi: FitnessProfileModel.calculateBmi(80.0, 180.0),
      medicalHistory: 'None',
      physicalLimitations: 'None',
      fitnessNotes: 'Avid hiker',
      updatedAt: DateTime.now().toIso8601String(),
    );

    await profileRepo.saveProfile(profile);

    // 3. Retrieve profile
    final retrieved = await profileRepo.getProfileByUserId(userId);
    expect(retrieved, isNotNull);
    expect(retrieved!.fullName, equals('Test User Full'));
    expect(retrieved.age, equals(30));
    expect(retrieved.weightKg, equals(80.0));
    expect(retrieved.heightCm, equals(180.0));
    expect(retrieved.bmi, closeTo(24.69, 0.1));
  });

  test('User Data Isolation Test', () async {
    final dbHelper = DatabaseHelper.instance;
    final profileRepo = FitnessProfileRepository(dbHelper);

    final user1Id = await profileRepo.getOrCreateUserIdByEmail('user1@venture.com', 'User One');
    final user2Id = await profileRepo.getOrCreateUserIdByEmail('user2@venture.com', 'User Two');

    await profileRepo.saveProfile(FitnessProfileModel(
      userId: user1Id,
      fullName: 'Profile One',
      age: 25,
      gender: 'Female',
      heightCm: 165.0,
      weightKg: 60.0,
      bmi: 22.0,
      updatedAt: DateTime.now().toIso8601String(),
    ));

    final p1 = await profileRepo.getProfileByUserId(user1Id);
    final p2 = await profileRepo.getProfileByUserId(user2Id);

    expect(p1, isNotNull);
    expect(p1!.fullName, equals('Profile One'));
    expect(p2, isNull); // User 2 has no profile yet
  });
}
