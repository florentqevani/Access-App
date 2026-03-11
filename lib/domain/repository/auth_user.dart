class AuthPermission {
  final String resource;
  final String action;
  final String scope;

  const AuthPermission({
    required this.resource,
    required this.action,
    required this.scope,
  });

  String get key => '$resource:$action';
}

class AuthUser {
  final String id;
  final String? email;
  final String? displayName;
  final String role;
  final List<AuthPermission> permissions;

  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.permissions,
  });

  String _legacyPermissionScope(String resource, String action) {
    if (resource != 'users') {
      return 'none';
    }

    if (action == 'read') {
      return _permissionScopeByKey(resource: resource, action: 'view');
    }

    if (action == 'create' || action == 'edit') {
      return _permissionScopeByKey(resource: resource, action: 'manage');
    }

    return 'none';
  }

  String _permissionScopeByKey({
    required String resource,
    required String action,
  }) {
    for (final permission in permissions) {
      if (permission.resource == resource && permission.action == action) {
        return permission.scope;
      }
    }
    return 'none';
  }

  String permissionScope(String resource, String action) {
    final scope = _permissionScopeByKey(resource: resource, action: action);
    if (scope != 'none') {
      return scope;
    }

    return _legacyPermissionScope(resource, action);
  }

  bool hasPermission(String resource, String action) {
    return permissionScope(resource, action) != 'none';
  }
}
