import '../domain/preference_models.dart';

/// Fail-closed, UI-facing projection of the owner privacy defaults.
///
/// Consumers use [safeFallback] while the authoritative preference is loading
/// or unavailable. This prevents a transient network/auth error from silently
/// making a Rescue post, comment or chat less private.
class PrivacySurfacePolicy {
  const PrivacySurfacePolicy({
    required this.hideHouseNumber,
    required this.hidePhoneByDefault,
    required this.reviewMediaBeforePublish,
    this.sourceVersion,
  });

  const PrivacySurfacePolicy.safeFallback()
    : hideHouseNumber = true,
      hidePhoneByDefault = true,
      reviewMediaBeforePublish = true,
      sourceVersion = null;

  factory PrivacySurfacePolicy.fromDefaults(PrivacyDefaults defaults) {
    return PrivacySurfacePolicy(
      hideHouseNumber: defaults.hideHouseNumber,
      hidePhoneByDefault: defaults.hidePhoneByDefault,
      reviewMediaBeforePublish: defaults.reviewMediaBeforePublish,
      sourceVersion: defaults.version,
    );
  }

  static const defaultSafe = PrivacySurfacePolicy.safeFallback();

  final bool hideHouseNumber;
  final bool hidePhoneByDefault;
  final bool reviewMediaBeforePublish;
  final int? sourceVersion;

  bool requiresPhoneConsent(String text) =>
      hidePhoneByDefault && containsPhoneNumber(text);

  bool requiresMediaReview(Iterable<Object?> media) =>
      reviewMediaBeforePublish && media.isNotEmpty;

  String redactHouseNumber(String address) {
    final value = address.trim();
    if (!hideHouseNumber || value.isEmpty) return value;
    return value
        .replaceFirst(
          RegExp(
            r'^\s*(?:số\s+)?\d+[A-Za-zÀ-ỹ]?(?:[\/-]\d+[A-Za-zÀ-ỹ]?)?\s*[,.-]?\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }

  static bool containsPhoneNumber(String text) {
    final compact = text.replaceAll(RegExp(r'[\s().-]'), '');
    return RegExp(r'(?<!\d)(?:\+?84|0)\d{9,10}(?!\d)').hasMatch(compact);
  }
}
