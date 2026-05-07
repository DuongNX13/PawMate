import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/storage/secure_storage_service.dart';
import 'auth_api.dart';

final authSessionStoreProvider = Provider<AuthSessionStore>((ref) {
  return AuthSessionStore(ref.watch(secureStorageProvider));
});

class AuthSessionStore {
  AuthSessionStore(this._storage);

  static const _sessionKey = 'pawmate.auth.session';

  final FlutterSecureStorage _storage;

  Future<void> save(AuthSession session) async {
    await _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
  }

  Future<AuthSession?> read() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    return AuthSession.fromJson(decoded);
  }

  Future<void> clear() async {
    await _storage.delete(key: _sessionKey);
  }
}
