import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';

class FitnessProfileModel {
  final int? id;
  final int userId;
  final String fullName;
  final int age;
  final String gender;
  final double heightCm;
  final double weightKg;
  final double bmi;
  final String? medicalHistory;
  final String? physicalLimitations;
  final String? fitnessNotes;
  final String updatedAt;

  FitnessProfileModel({
    this.id,
    required this.userId,
    required this.fullName,
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.bmi,
    this.medicalHistory,
    this.physicalLimitations,
    this.fitnessNotes,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'full_name': fullName,
      'age': age,
      'gender': gender,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'bmi': bmi,
      'medical_history': medicalHistory,
      'physical_limitations': physicalLimitations,
      'fitness_notes': fitnessNotes,
      'updated_at': updatedAt,
    };
  }

  factory FitnessProfileModel.fromMap(Map<String, dynamic> map) {
    return FitnessProfileModel(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      fullName: map['full_name'] as String,
      age: map['age'] as int,
      gender: map['gender'] as String,
      heightCm: map['height_cm'] as double,
      weightKg: map['weight_kg'] as double,
      bmi: map['bmi'] as double,
      medicalHistory: map['medical_history'] as String?,
      physicalLimitations: map['physical_limitations'] as String?,
      fitnessNotes: map['fitness_notes'] as String?,
      updatedAt: map['updated_at'] as String,
    );
  }

  static double calculateBmi(double weightKg, double heightCm) {
    if (heightCm <= 0) return 0.0;
    final heightM = heightCm / 100.0;
    return weightKg / (heightM * heightM);
  }
}

class FitnessProfileRepository {
  final DatabaseHelper databaseHelper;

  FitnessProfileRepository(this.databaseHelper);

  Future<int> getOrCreateUserIdByEmail(String email, String username) async {
    return await getOrCreateLocalUserId(email: email, username: username);
  }

  Future<int> getOrCreateLocalUserId({
    required String email,
    required String username,
    String? backendUserId,
  }) async {
    final db = await databaseHelper.database;

    if (backendUserId != null && backendUserId.isNotEmpty) {
      final byBackendId = await db.query('users', where: 'backend_user_id = ?', whereArgs: [backendUserId]);
      if (byBackendId.isNotEmpty) {
        return byBackendId.first['id'] as int;
      }
    }

    final byEmail = await db.query('users', where: 'email = ?', whereArgs: [email]);
    if (byEmail.isNotEmpty) {
      final localUser = byEmail.first;
      final localId = localUser['id'] as int;
      if (backendUserId != null && backendUserId.isNotEmpty && localUser['backend_user_id'] == null) {
        await db.update('users', {'backend_user_id': backendUserId}, where: 'id = ?', whereArgs: [localId]);
      }
      return localId;
    }

    return await db.insert('users', {
      'backend_user_id': backendUserId,
      'username': username,
      'email': email,
      'password_hash': 'SERVER_MANAGED_HASH',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> saveProfile(FitnessProfileModel profile) async {
    final db = await databaseHelper.database;
    final existing = await db.query('fitness_profiles', where: 'user_id = ?', whereArgs: [profile.userId]);

    if (existing.isNotEmpty) {
      await db.update(
        'fitness_profiles',
        profile.toMap(),
        where: 'user_id = ?',
        whereArgs: [profile.userId],
      );
    } else {
      await db.insert('fitness_profiles', profile.toMap());
    }
  }

  Future<FitnessProfileModel?> getProfileByUserId(int userId) async {
    final db = await databaseHelper.database;
    final result = await db.query('fitness_profiles', where: 'user_id = ?', whereArgs: [userId]);
    if (result.isNotEmpty) {
      return FitnessProfileModel.fromMap(result.first);
    }
    return null;
  }
}

final fitnessProfileRepositoryProvider = Provider<FitnessProfileRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return FitnessProfileRepository(dbHelper);
});
