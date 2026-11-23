import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/adoption_request_chat_models.dart';

final adoptionRequestChatDraftStoreProvider =
    Provider<AdoptionRequestChatDraftStore>((ref) {
      return SharedPreferencesAdoptionRequestChatDraftStore();
    });

abstract interface class AdoptionRequestChatDraftStore {
  Future<AdoptionRequestDraft> readRequestDraft({
    required String userId,
    required String listingId,
  });

  Future<void> saveRequestDraft({
    required String userId,
    required String listingId,
    required AdoptionRequestDraft draft,
  });

  Future<void> clearRequestDraft({
    required String userId,
    required String listingId,
  });

  Future<AdoptionChatDraft> readChatDraft({
    required String userId,
    required String threadId,
  });

  Future<void> saveChatDraft({
    required String userId,
    required String threadId,
    required AdoptionChatDraft draft,
  });

  Future<void> clearChatDraft({
    required String userId,
    required String threadId,
  });

  Future<AdoptionChatContext?> readChatContext({
    required String userId,
    required String threadId,
  });

  Future<void> saveChatContext({
    required String userId,
    required String threadId,
    required AdoptionChatContext context,
  });
}

class SharedPreferencesAdoptionRequestChatDraftStore
    implements AdoptionRequestChatDraftStore {
  Future<void> _writeTail = Future.value();

  @override
  Future<AdoptionRequestDraft> readRequestDraft({
    required String userId,
    required String listingId,
  }) async {
    await _writeTail;
    final raw = (await SharedPreferences.getInstance()).getString(
      _key('request', userId, listingId),
    );
    if (raw == null) return const AdoptionRequestDraft();
    try {
      final decoded = jsonDecode(raw);
      return AdoptionRequestDraft.fromJson(_readMap(decoded));
    } on Object {
      return const AdoptionRequestDraft();
    }
  }

  @override
  Future<void> saveRequestDraft({
    required String userId,
    required String listingId,
    required AdoptionRequestDraft draft,
  }) {
    return _enqueue(() async {
      final saved = await (await SharedPreferences.getInstance()).setString(
        _key('request', userId, listingId),
        jsonEncode(draft.toJson()),
      );
      if (!saved) {
        throw StateError('Unable to persist Adoption request draft.');
      }
    });
  }

  @override
  Future<void> clearRequestDraft({
    required String userId,
    required String listingId,
  }) {
    return _enqueue(() async {
      final removed = await (await SharedPreferences.getInstance()).remove(
        _key('request', userId, listingId),
      );
      if (!removed) {
        final preferences = await SharedPreferences.getInstance();
        if (preferences.containsKey(_key('request', userId, listingId))) {
          throw StateError('Unable to clear Adoption request draft.');
        }
      }
    });
  }

  @override
  Future<AdoptionChatDraft> readChatDraft({
    required String userId,
    required String threadId,
  }) async {
    await _writeTail;
    final raw = (await SharedPreferences.getInstance()).getString(
      _key('chat', userId, threadId),
    );
    if (raw == null) return const AdoptionChatDraft();
    try {
      final decoded = jsonDecode(raw);
      return AdoptionChatDraft.fromJson(_readMap(decoded));
    } on Object {
      return const AdoptionChatDraft();
    }
  }

  @override
  Future<void> saveChatDraft({
    required String userId,
    required String threadId,
    required AdoptionChatDraft draft,
  }) {
    return _enqueue(() async {
      final saved = await (await SharedPreferences.getInstance()).setString(
        _key('chat', userId, threadId),
        jsonEncode(draft.toJson()),
      );
      if (!saved) {
        throw StateError('Unable to persist Adoption chat draft.');
      }
    });
  }

  @override
  Future<void> clearChatDraft({
    required String userId,
    required String threadId,
  }) {
    return _enqueue(() async {
      final preferences = await SharedPreferences.getInstance();
      final key = _key('chat', userId, threadId);
      final removed = await preferences.remove(key);
      if (!removed && preferences.containsKey(key)) {
        throw StateError('Unable to clear Adoption chat draft.');
      }
    });
  }

  @override
  Future<AdoptionChatContext?> readChatContext({
    required String userId,
    required String threadId,
  }) async {
    await _writeTail;
    final raw = (await SharedPreferences.getInstance()).getString(
      _key('context', userId, threadId),
    );
    if (raw == null) return null;
    try {
      return AdoptionChatContext.fromJson(_readMap(jsonDecode(raw)));
    } on Object {
      return null;
    }
  }

  @override
  Future<void> saveChatContext({
    required String userId,
    required String threadId,
    required AdoptionChatContext context,
  }) {
    return _enqueue(() async {
      final saved = await (await SharedPreferences.getInstance()).setString(
        _key('context', userId, threadId),
        jsonEncode(context.toJson()),
      );
      if (!saved) {
        throw StateError('Unable to persist Adoption chat context.');
      }
    });
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _writeTail.then((_) => action());
    _writeTail = next.catchError((_) {});
    return next;
  }

  static String _key(String kind, String userId, String resourceId) {
    final scope = base64Url.encode(
      utf8.encode('${userId.trim()}\u0000${resourceId.trim()}'),
    );
    return 'pawmate.adoption.$kind.v1.$scope';
  }
}

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw const FormatException('Invalid Adoption local draft.');
}
