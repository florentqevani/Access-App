function permissionKey(resource, action) {
  return `${resource}:${action}`;
}

function permissionAliases(resource, action) {
  if (resource !== "users") {
    return [];
  }

  if (action === "read") {
    return [permissionKey(resource, "view")];
  }

  if (action === "create" || action === "edit") {
    return [permissionKey(resource, "manage")];
  }

  return [];
}

export function resolvePermissionScope(req, resource, action) {
  const key = permissionKey(resource, action);
  const aliases = permissionAliases(resource, action);
  const scopeMap =
    req.user && typeof req.user.permissionScopes === "object"
      ? req.user.permissionScopes
      : null;

  if (scopeMap && typeof scopeMap[key] === "string") {
    return scopeMap[key];
  }
  if (scopeMap) {
    for (const alias of aliases) {
      if (typeof scopeMap[alias] === "string") {
        return scopeMap[alias];
      }
    }
  }

  const permissionCodes = Array.isArray(req.user?.permissions)
    ? req.user.permissions
    : [];
  if (permissionCodes.includes(key)) {
    return "full";
  }
  for (const alias of aliases) {
    if (permissionCodes.includes(alias)) {
      return "full";
    }
  }

  return "none";
}

export default function requirePermission(resource, action) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const scope = resolvePermissionScope(req, resource, action);
    if (scope === "none") {
      return res
        .status(403)
        .json({ error: "Forbidden: Missing required permission" });
    }

    req.permission = {
      resource,
      action,
      scope,
      key: permissionKey(resource, action),
    };
    return next();
  };
}
