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
  const RegisterResponse({
    required this.userId,
    required this.message,
    this.verificationStatus = 'pending',
    this.verificationExpiresAt,
    this.resendAvailableAt,
  });

  final String userId;
  final String message;
  final String verificationStatus;
  final DateTime? verificationExpiresAt;
  final DateTime? resendAvailableAt;

  bool get requiresVerification => verificationStatus != 'verified';

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    return RegisterResponse(
      userId: json['userId']?.toString() ?? '',
      message: json['message']?.toString() ?? 'Hãy kiểm tra email của bạn',
      verificationStatus: json['verificationStatus']?.toString() ?? 'pending',
      verificationExpiresAt: _readDateTime(json['verificationExpiresAt']),
      resendAvailableAt: _readDateTime(json['resendAvailableAt']),
    );
  }
}

class ResendVerificationResponse {
  const ResendVerificationResponse({
    required this.message,
    this.verificationStatus = 'pending',
    this.verificationExpiresAt,
    this.resendAvailableAt,
  });

  final String message;
  final String verificationStatus;
  final DateTime? verificationExpiresAt;
  final DateTime? resendAvailableAt;

  factory ResendVerificationResponse.fromJson(Map<String, dynamic> json) {
    return ResendVerificationResponse(
      message: json['message']?.toString() ?? 'Đã gửi lại email xác minh',
      verificationStatus: json['verificationStatus']?.toString() ?? 'pending',
      verificationExpiresAt: _readDateTime(json['verificationExpiresAt']),
      resendAvailableAt: _readDateTime(json['resendAvailableAt']),
    );
  }
}

class VerifyEmailResponse {
  const VerifyEmailResponse({
    required this.userId,
    required this.email,
    required this.message,
    this.session,
  });

  final String userId;
  final String email;
  final String message;
  final AuthSession? session;

  factory VerifyEmailResponse.fromJson(
    Map<String, dynamic> json, {
    String fallbackEmail = '',
  }) {
    final hasSession =
        json['accessToken'] != null &&
        json['refreshToken'] != null &&
        json['user'] != null;

    return VerifyEmailResponse(
      userId: json['userId']?.toString() ?? '',
      email: json['email']?.toString() ?? fallbackEmail,
      message: json['message']?.toString() ?? 'Email đã được xác minh',
      session: hasSession ? AuthSession.fromJson(json) : null,
    );
  }
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
    required String phone,
    String? displayName,
  }) async {
    return _perform(
      request: () => _dio.post(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          'phone': phone.trim(),
          if (displayName != null && displayName.trim().isNotEmpty)
            'displayName': displayName.trim(),
        },
      ),
      parser: RegisterResponse.fromJson,
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
      parser: (json) =>
          VerifyEmailResponse.fromJson(json, fallbackEmail: email),
    );
  }

  Future<ResendVerificationResponse> resendVerification({
    required String email,
  }) async {
    return _perform(
      request: () =>
          _dio.post('/auth/resend-verification', data: {'email': email}),
      parser: ResendVerificationResponse.fromJson,
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

  Future<AuthSession> refresh({required String refreshToken}) async {
    return _perform(
      request: () =>
          _dio.post('/auth/refresh', data: {'refreshToken': refreshToken}),
      parser: AuthSession.fromJson,
    );
  }

  Future<void> logout({required String refreshToken}) async {
    try {
      await _dio.post('/auth/logout', data: {'refreshToken': refreshToken});
    } on DioException catch (error) {
      throw _toApiException(error);
    }
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

DateTime? _readDateTime(dynamic value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text)?.toLocal();
}
