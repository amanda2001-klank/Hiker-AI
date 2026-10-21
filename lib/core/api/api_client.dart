import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum Environment { emulator, physicalDevice, production }

class ApiEnvironmentConfig {
  static const String customUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const String envString = String.fromEnvironment('ENV', defaultValue: 'emulator');

  static Environment get current {
    if (envString == 'physicalDevice') return Environment.physicalDevice;
    if (envString == 'production') return Environment.production;
    return Environment.emulator;
  }

  static String get baseUrl {
    if (customUrl.isNotEmpty) {
      return customUrl;
    }
    switch (current) {
      case Environment.emulator:
        return 'http://10.0.2.2:8002/api/v1';
      case Environment.physicalDevice:
        return 'http://127.0.0.1:8002/api/v1';
      case Environment.production:
        return 'https://api.ventureapp.com/api/v1';
    }
  }
}

class ApiResponse<T> {
  final String message;
  final T? data;
  final Map<String, dynamic>? meta;

  ApiResponse({required this.message, this.data, this.meta});

  factory ApiResponse.fromJson(Map<String, dynamic> json, T Function(dynamic) fromJsonData) {
    return ApiResponse(
      message: json['message'] as String? ?? '',
      data: json['data'] != null ? fromJsonData(json['data']) : null,
      meta: json['meta'] as Map<String, dynamic>?,
    );
  }
}

class ApiClient {
  late final Dio dio;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiEnvironmentConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Secure log interceptor without sensitive tokens or passwords
    dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        requestHeader: false,
        responseHeader: false,
      ),
    );
  }

  void setAuthToken(String token) {
    dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearAuthToken() {
    dio.options.headers.remove('Authorization');
  }

  Future<ApiResponse<T>> handleRequest<T>(
      Future<Response> Function() request,
      T Function(dynamic) fromJsonData,
      ) async {
    try {
      final response = await request();
      final body = response.data;
      if (body is Map<String, dynamic>) {
        return ApiResponse.fromJson(body, fromJsonData);
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          error: 'Invalid response envelope format',
        );
      }
    } on DioException {
      rethrow;
    }
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
