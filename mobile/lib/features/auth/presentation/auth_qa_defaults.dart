const pawmateQaPrefillAuth = bool.fromEnvironment('PAWMATE_QA_PREFILL_AUTH');

const pawmateQaAuthPassword = String.fromEnvironment(
  'PAWMATE_QA_AUTH_PASSWORD',
  defaultValue: 'pawmate1',
);

final pawmateQaAuthEmail = _buildQaAuthEmail();

String _buildQaAuthEmail() {
  final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
  return 'qa$timestamp@example.com';
}
