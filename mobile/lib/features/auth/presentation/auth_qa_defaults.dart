const pawmateQaPrefillAuth = bool.fromEnvironment('PAWMATE_QA_PREFILL_AUTH');

const pawmateQaAutorunAuthSmoke = bool.fromEnvironment(
  'PAWMATE_QA_AUTORUN_AUTH_SMOKE',
);

const _pawmateQaAuthPasswordOverride = String.fromEnvironment(
  'PAWMATE_QA_AUTH_PASSWORD',
);

const _pawmateQaAuthEmailOverride = String.fromEnvironment(
  'PAWMATE_QA_AUTH_EMAIL',
);

final pawmateQaAuthEmail = _buildQaAuthEmail();
final pawmateQaAuthPassword = _buildQaAuthPassword();

String _buildQaAuthPassword() {
  final configuredPassword = _pawmateQaAuthPasswordOverride.trim();
  if (configuredPassword.isNotEmpty) {
    return configuredPassword;
  }

  return 'pawmate1';
}

String _buildQaAuthEmail() {
  final configuredEmail = _pawmateQaAuthEmailOverride.trim();
  if (configuredEmail.isNotEmpty) {
    return configuredEmail;
  }

  final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
  return 'qa$timestamp@example.com';
}
