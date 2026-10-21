import 'package:flutter/services.dart';

class OnnxExertionService {
  static const MethodChannel _channel =
      MethodChannel('com.example.app_venture_flutter/onnx_ai');

  Future<double> predictExertion({
    required double heartRate,
    required double age,
    required double fitnessYears,
    required double sleepingHours,
  }) async {
    if (!heartRate.isFinite || heartRate < 60 || heartRate > 99) {
      throw ArgumentError('Heart rate outside permitted input range');
    }

    if (!age.isFinite || age <= 0 || age > 120) {
      throw ArgumentError('Invalid age');
    }

    if (!fitnessYears.isFinite ||
        fitnessYears < 0 ||
        fitnessYears > age) {
      throw ArgumentError('Invalid fitness training years');
    }

    if (!sleepingHours.isFinite ||
        sleepingHours < 0 ||
        sleepingHours > 24) {
      throw ArgumentError('Invalid sleeping hours');
    }

    final result = await _channel.invokeMethod<double>(
      'predictExertion',
      <String, dynamic>{
        'heartRate': heartRate,
        'age': age,
        'fitnessYears': fitnessYears,
        'sleepingHours': sleepingHours,
      },
    );

    if (result == null || !result.isFinite) {
      throw StateError('ONNX returned an invalid prediction');
    }

    return result;
  }
}
