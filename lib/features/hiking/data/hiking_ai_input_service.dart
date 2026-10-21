import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../fitness/data/fitness_profile_repository.dart';

class HikingAiProfileInputs {
  final double age;
  final double fitnessYears;
  final double sleepingHours;

  const HikingAiProfileInputs({
    required this.age,
    required this.fitnessYears,
    required this.sleepingHours,
  });
}

class HikingAiInputService {
  final FitnessProfileRepository _profiles;

  HikingAiInputService(this._profiles);

  Future<double?> getSavedAge(int userId) async {
    final profile = await _profiles.getProfileByUserId(userId);
    if (profile == null) return null;

    final age = profile.age.toDouble();
    if (age <= 0 || age > 120) return null;

    return age;
  }

  HikingAiProfileInputs? validateInputs({
    required double? age,
    required double? fitnessYears,
    required double? sleepingHours,
  }) {
    if (age == null ||
        !age.isFinite ||
        age <= 0 ||
        age > 120) {
      return null;
    }

    if (fitnessYears == null ||
        !fitnessYears.isFinite ||
        fitnessYears < 0 ||
        fitnessYears > age) {
      return null;
    }

    if (sleepingHours == null ||
        !sleepingHours.isFinite ||
        sleepingHours < 0 ||
        sleepingHours > 24) {
      return null;
    }

    return HikingAiProfileInputs(
      age: age,
      fitnessYears: fitnessYears,
      sleepingHours: sleepingHours,
    );
  }
}

final hikingAiInputServiceProvider = Provider<HikingAiInputService>((ref) {
  final repository = ref.watch(fitnessProfileRepositoryProvider);
  return HikingAiInputService(repository);
});
