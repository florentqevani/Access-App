export const ROLE_NAMES = Object.freeze({
  ADMIN: "admin",
  MANAGER: "manager",
  USER: "user",
  GUEST: "guest",
});

export const ROLE_DESCRIPTIONS = Object.freeze({
  [ROLE_NAMES.ADMIN]: "Full system access including role management.",
  [ROLE_NAMES.MANAGER]:
    "Team-level management with reporting access and limited user management.",
  [ROLE_NAMES.USER]: "Standard user with self-service access.",
  [ROLE_NAMES.GUEST]: "Restricted account with minimal read access.",
});

export const PERMISSION_SCOPE = Object.freeze({
  NONE: "none",
  OWN: "own",
  TEAM: "team",
  LIMITED: "limited",
  FULL: "full",
});

export const RBAC_PERMISSIONS = Object.freeze([
  {
    resource: "dashboard",
    action: "view",
    description: "View dashboard",
  },
  {
    resource: "users",
    action: "read",
    description: "Read users",
  },
  {
    resource: "users",
    action: "create",
    description: "Create users",
  },
  {
    resource: "users",
    action: "edit",
    description: "Edit users",
  },
  {
    resource: "users",
    action: "delete",
    description: "Delete users",
  },
  {
    resource: "reports",
    action: "read",
    description: "Read reports",
  },
  {
    resource: "reports",
    action: "export",
    description: "Export reports",
  },
  {
    resource: "settings",
    action: "configure",
    description: "Configure system settings",
  },
  {
    resource: "audit_logs",
    action: "view",
    description: "View audit logs",
  },
  {
    resource: "roles",
    action: "manage",
    description: "Manage user roles",
  },
]);

export function permissionKey(resource, action) {
  return `${resource}:${action}`;
}

export const ROLE_PERMISSION_SCOPES = Object.freeze({
  [ROLE_NAMES.ADMIN]: {
    "dashboard:view": PERMISSION_SCOPE.FULL,
    "users:read": PERMISSION_SCOPE.FULL,
    "users:create": PERMISSION_SCOPE.FULL,
    "users:edit": PERMISSION_SCOPE.FULL,
    "users:delete": PERMISSION_SCOPE.FULL,
    "reports:read": PERMISSION_SCOPE.FULL,
    "reports:export": PERMISSION_SCOPE.FULL,
    "settings:configure": PERMISSION_SCOPE.FULL,
    "audit_logs:view": PERMISSION_SCOPE.FULL,
    "roles:manage": PERMISSION_SCOPE.FULL,
  },
  [ROLE_NAMES.MANAGER]: {
    "dashboard:view": PERMISSION_SCOPE.FULL,
    "users:read": PERMISSION_SCOPE.TEAM,
    "users:create": PERMISSION_SCOPE.NONE,
    "users:edit": PERMISSION_SCOPE.TEAM,
    "users:delete": PERMISSION_SCOPE.NONE,
    "reports:read": PERMISSION_SCOPE.FULL,
    "reports:export": PERMISSION_SCOPE.FULL,
    "settings:configure": PERMISSION_SCOPE.NONE,
    "audit_logs:view": PERMISSION_SCOPE.OWN,
    "roles:manage": PERMISSION_SCOPE.NONE,
  },
  [ROLE_NAMES.USER]: {
    "dashboard:view": PERMISSION_SCOPE.LIMITED,
    "users:read": PERMISSION_SCOPE.OWN,
    "users:create": PERMISSION_SCOPE.NONE,
    "users:edit": PERMISSION_SCOPE.NONE,
    "users:delete": PERMISSION_SCOPE.NONE,
    "reports:read": PERMISSION_SCOPE.OWN,
    "reports:export": PERMISSION_SCOPE.NONE,
    "settings:configure": PERMISSION_SCOPE.NONE,
    "audit_logs:view": PERMISSION_SCOPE.NONE,
    "roles:manage": PERMISSION_SCOPE.NONE,
  },
  [ROLE_NAMES.GUEST]: {
    "dashboard:view": PERMISSION_SCOPE.NONE,
    "users:read": PERMISSION_SCOPE.NONE,
    "users:create": PERMISSION_SCOPE.NONE,
    "users:edit": PERMISSION_SCOPE.NONE,
    "users:delete": PERMISSION_SCOPE.NONE,
    "reports:read": PERMISSION_SCOPE.NONE,
    "reports:export": PERMISSION_SCOPE.NONE,
    "settings:configure": PERMISSION_SCOPE.NONE,
    "audit_logs:view": PERMISSION_SCOPE.NONE,
    "roles:manage": PERMISSION_SCOPE.NONE,
  },
});
