import '../../../app/router/app_route_registry.dart';

const defaultAuthenticatedRoute = '/pets';

String resolveAuthenticatedReturnRoute(String? rawReturnTo) {
  return sanitizeAuthenticatedReturnRoute(rawReturnTo) ??
      defaultAuthenticatedRoute;
}

String? sanitizeAuthenticatedReturnRoute(String? rawReturnTo) {
  final value = rawReturnTo?.trim();
  if (value == null ||
      value.isEmpty ||
      !value.startsWith('/') ||
      value.startsWith('//')) {
    return null;
  }

  final uri = Uri.tryParse(value);
  if (uri == null) {
    return null;
  }
  final normalizedPath = uri.path.toLowerCase();
  if (uri.hasScheme ||
      uri.hasAuthority ||
      value.contains(r'\') ||
      uri.path.startsWith('//') ||
      normalizedPath.contains('%2f') ||
      normalizedPath.contains('%5c')) {
    return null;
  }
  if (uri.path.startsWith('/auth/') ||
      uri.path == '/launch' ||
      uri.path == '/onboarding') {
    return null;
  }
  return AppRouteRegistry.isSupportedAuthenticatedUri(uri)
      ? uri.toString()
      : null;
}

Map<String, String> authQueryParameters({
  Map<String, String> values = const {},
  String? returnTo,
}) {
  final safeReturnTo = sanitizeAuthenticatedReturnRoute(returnTo);
  final result = <String, String>{...values};
  if (safeReturnTo != null) {
    result['returnTo'] = safeReturnTo;
  }
  return result;
}
