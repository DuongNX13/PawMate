import 'package:pawmate_mobile/features/preferences/application/preference_providers.dart';
import 'package:pawmate_mobile/features/preferences/domain/preference_models.dart';

/// Deterministic safe defaults for local layout proofs; never calls a server.
class Day120PrivacyFixture extends PrivacyDefaultsNotifier {
  @override
  Future<PrivacyDefaults> build() async => PrivacyDefaults(
    userId: 'day120-fixture',
    version: 1,
    hideHouseNumber: true,
    hidePhoneByDefault: true,
    reviewMediaBeforePublish: true,
    updatedAt: DateTime.utc(2026, 10, 19),
  );
}
