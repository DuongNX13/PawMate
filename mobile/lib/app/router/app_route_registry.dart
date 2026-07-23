/// Canonical route registry used by auth return-route validation and shell
/// navigation. Keeping validation separate from the router avoids accepting an
/// arbitrary internal-looking path as an authenticated destination.
abstract final class AppRouteRegistry {
  static const shellRoots = <String>[
    '/pets',
    '/vets/map',
    '/health',
    '/rescue',
    '/profile',
  ];

  static const _exactAuthenticatedPaths = <String>{
    '/pets',
    '/pets/list',
    '/pets/create',
    '/vets/map',
    '/vets/list',
    '/health',
    '/health/events/new',
    '/health/reminders',
    '/notifications',
    '/community',
    '/adoption',
    '/profile',
    '/profile/controls',
    '/profile/privacy',
    '/rescue',
    '/rescue/create',
    '/rescue/create/details',
    '/rescue/map',
  };

  static bool isSupportedAuthenticatedUri(Uri uri) {
    if (uri.hasScheme || uri.hasAuthority || uri.fragment.isNotEmpty) {
      return false;
    }
    final path = uri.path;
    if (!path.startsWith('/') || path.startsWith('//')) return false;
    if (_exactAuthenticatedPaths.contains(path)) return true;

    final segments = uri.pathSegments;
    if (!_segmentsAreSafe(segments)) return false;
    return switch (segments) {
      ['pets', final id] => _isSafeId(id),
      ['pets', final id, 'edit'] => _isSafeId(id),
      ['vets', final id] => _isSafeId(id),
      ['rescue', final caseId] => _isSafeId(caseId),
      ['rescue', final caseId, final action]
          when const {'comment', 'status', 'discussion'}.contains(action) =>
        _isSafeId(caseId),
      _ => false,
    };
  }

  static bool isSupportedAuthenticatedLocation(String location) {
    final uri = Uri.tryParse(location);
    return uri != null && isSupportedAuthenticatedUri(uri);
  }

  static int? shellBranchIndexForLocation(String location) {
    final uri = Uri.tryParse(location);
    if (uri == null) return null;
    final path = uri.path;
    if (path == '/pets' || path == '/pets/list' || path == '/adoption') {
      return 0;
    }
    if (path == '/vets/map' || path == '/vets/list') return 1;
    if (path == '/health' || path == '/health/reminders') return 2;
    if (path == '/rescue' || path == '/rescue/map') return 3;
    if (path == '/profile' ||
        path == '/profile/controls' ||
        path == '/profile/privacy' ||
        path == '/notifications') {
      return 4;
    }
    return null;
  }

  static bool _segmentsAreSafe(List<String> segments) {
    return segments.isNotEmpty && segments.every(_isSafeSegment);
  }

  static bool _isSafeSegment(String value) {
    return value.isNotEmpty &&
        value != '.' &&
        value != '..' &&
        !value.contains('/') &&
        !value.contains(r'\');
  }

  static bool _isSafeId(String value) {
    if (!_isSafeSegment(value)) return false;
    return RegExp(r'^[A-Za-z0-9][A-Za-z0-9._~-]*$').hasMatch(value);
  }
}
