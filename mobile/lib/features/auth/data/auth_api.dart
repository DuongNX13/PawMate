import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_dio.dart';

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(dioProvider));
});

class AuthApiException implements Exception {
  const AuthApiException(
    this.message, {
    this.code,
    this.field,
    this.statusCode,
  });

  final String message;
  final String? code;
  final String? field;
  final int? statusCode;

  @override
  String toString() => message;
}

class RegisterResponse {
  const RegisterResponse({required this.userId, required this.message});

  final String userId;
  final String message;
}

class VerifyEmailResponse {
  const VerifyEmailResponse({
    required this.userId,
    required this.email,
    required this.message,
  });

  final String userId;
  final String email;
  final String message;
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.authProvider,
    required this.emailVerified,
    this.displayName,
    this.phone,
  });

  final String id;
  final String email;
  final String authProvider;
  final bool emailVerified;
  final String? displayName;
  final String? phone;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      authProvider: json['authProvider']?.toString() ?? 'email',
      emailVerified: json['emailVerified'] == true,
      displayName: json['displayName']?.toString(),
      phone: json['phone']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'authProvider': authProvider,
      'emailVerified': emailVerified,
      'displayName': displayName,
      'phone': phone,
    };
  }
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresAt,
  });

  final AuthUser user;
  final String accessToken;
  final String refreshToken;
  final String accessTokenExpiresAt;
  final String refreshTokenExpiresAt;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      user: AuthUser.fromJson(_readMap(json['user'])),
      accessToken: json['accessToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      accessTokenExpiresAt: json['accessTokenExpiresAt']?.toString() ?? '',
      refreshTokenExpiresAt: json['refreshTokenExpiresAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'accessTokenExpiresAt': accessTokenExpiresAt,
      'refreshTokenExpiresAt': refreshTokenExpiresAt,
    };
  }
}

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<RegisterResponse> register({
    required String email,
    required String password,
    String? phone,
    String? displayName,
  }) async {
    return _perform(
      request: () => _dio.post(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
          if (displayName != null && displayName.trim().isNotEmpty)
            'displayName': displayName.trim(),
        },
      ),
      parser: (json) => RegisterResponse(
        userId: json['userId']?.toString() ?? '',
        message: json['message']?.toString() ?? 'Check your email',
      ),
    );
  }

  Future<VerifyEmailResponse> verifyEmail({
    required String email,
    required String token,
  }) async {
    return _perform(
      request: () => _dio.post(
        '/auth/verify-email',
        data: {'email': email, 'token': token},
      ),
      parser: (json) => VerifyEmailResponse(
        userId: json['userId']?.toString() ?? '',
        email: json['email']?.toString() ?? email,
        message: json['message']?.toString() ?? 'Email verified',
      ),
    );
  }

  Future<String> resendVerification({required String email}) async {
    return _perform(
      request: () =>
          _dio.post('/auth/resend-verification', data: {'email': email}),
      parser: (json) =>
          json['message']?.toString() ?? 'Verification email resent',
    );
  }

  Future<AuthSession> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    return _perform(
      request: () => _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password, 'rememberMe': rememberMe},
      ),
      parser: AuthSession.fromJson,
    );
  }

  Future<T> _perform<T>({
    required Future<Response<dynamic>> Function() request,
    required T Function(Map<String, dynamic> json) parser,
  }) async {
    try {
      final response = await request();
      return parser(_readMap(response.data));
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  AuthApiException _toApiException(DioException error) {
    final response = error.response;
    final payload = response?.data;
    if (payload is Map<String, dynamic>) {
      final errorMap = payload['error'];
      if (errorMap is Map<String, dynamic>) {
        return AuthApiException(
          errorMap['message']?.toString() ?? _fallbackMessage(error),
          code: errorMap['code']?.toString(),
          field: errorMap['field']?.toString(),
          statusCode: response?.statusCode,
        );
      }
    }

    return AuthApiException(
      _fallbackMessage(error),
      statusCode: response?.statusCode,
    );
  }

  String _fallbackMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Không thể kết nối tới máy chủ PawMate.';
      default:
        return 'Đã có lỗi xảy ra. Vui lòng thử lại.';
    }
  }
}

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }
  throw const AuthApiException('Máy chủ trả về dữ liệu không hợp lệ.');
}
