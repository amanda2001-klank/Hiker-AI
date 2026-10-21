import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';

class UserAuthResponse {
  final String userId;
  final String username;
  final String email;
  final String? profileImageUrl;
  final double? fitnessScore;
  final String? token;

  UserAuthResponse({
    required this.userId,
    required this.username,
    required this.email,
    this.profileImageUrl,
    this.fitnessScore,
    this.token,
  });

  factory UserAuthResponse.fromJson(Map<String, dynamic> json) {
    return UserAuthResponse(
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      profileImageUrl: json['profile_image_url'] as String?,
      fitnessScore: json['fitness_score'] != null ? (json['fitness_score'] as num).toDouble() : null,
      token: json['token'] as String?,
    );
  }
}

class AuthRepository {
  final ApiClient apiClient;

  AuthRepository(this.apiClient);

  Future<ApiResponse<UserAuthResponse>> signup({
    required String email,
    required String password,
    required String username,
    String? profileImageUrl,
  }) async {
    try {
      return await apiClient.handleRequest(
            () => apiClient.dio.post('/signup', data: {
          'email': email,
          'password': password,
          'username': username,
          'profile_image_url': profileImageUrl,
        }),
            (data) => UserAuthResponse.fromJson(data is Map<String, dynamic> ? data : {}),
      );
    } on DioException catch (e) {
      throw _parseDioError(e);
    }
  }

  Future<ApiResponse<UserAuthResponse>> login({
    required String email,
    required String password,
  }) async {
    try {
      return await apiClient.handleRequest(
            () => apiClient.dio.post('/login', data: {
          'email': email,
          'password': password,
        }),
            (data) => UserAuthResponse.fromJson(data is Map<String, dynamic> ? data : {}),
      );
    } on DioException catch (e) {
      throw _parseDioError(e);
    }
  }

  String _parseDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError ||
        (e.message != null && e.message!.contains('connection'))) {
      return 'Unable to connect to FastAPI backend. Please check network/ADB connection.';
    }
    if (e.response != null) {
      if (e.response?.data is Map<String, dynamic>) {
        final data = e.response?.data as Map<String, dynamic>;
        if (data.containsKey('detail')) {
          return data['detail'].toString();
        }
        if (data.containsKey('message')) {
          return data['message'] as String;
        }
      }
      return 'Server error (${e.response?.statusCode}): ${e.response?.statusMessage ?? 'Internal Server Error'}';
    }
    return 'Unable to reach backend server. Please check your network connection.';
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthRepository(apiClient);
});
