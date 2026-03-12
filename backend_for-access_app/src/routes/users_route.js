import { Router } from "express";
import bcrypt from "bcryptjs";
import authenticate from "../middleware/auth_middleware.js";
import authorizeRole from "../middleware/role_middleware.js";
import requirePermission, {
  resolvePermissionScope,
} from "../middleware/permission_middleware.js";
import { db } from "../data/store.js";
import { sanitizeUser } from "../data/tokens.js";
import { RBAC_PERMISSIONS, ROLE_NAMES } from "../rbac/constants.js";

const router = Router();

const normalizedRoleAlias = new Map([
  ["admin", ROLE_NAMES.ADMIN],
  ["manager", ROLE_NAMES.MANAGER],
  ["menager", ROLE_NAMES.MANAGER],
  ["user", ROLE_NAMES.USER],
  ["guest", ROLE_NAMES.GUEST],
]);

const validDashboardActionKeys = new Set(
  RBAC_PERMISSIONS.map((permission) => {
    return `${permission.resource}:${permission.action}`;
  }),
);

function canScopeReadAll(scope) {
  return scope === "full" || scope === "team" || scope === "limited";
}

function canAccessUserByScope({ scope, actorUserId, targetUserId }) {
  if (scope === "full" || scope === "team" || scope === "limited") {
    return true;
  }
  if (scope === "own") {
    return actorUserId === targetUserId;
  }
  return false;
}

function getClientIp(req) {
  const forwardedFor = req.headers["x-forwarded-for"];
  if (typeof forwardedFor === "string" && forwardedFor.trim().length > 0) {
    return forwardedFor.split(",")[0].trim();
  }
  const remoteIp = req.ip || req.socket?.remoteAddress || null;
  if (typeof remoteIp !== "string") {
    return null;
  }
  return remoteIp.startsWith("::ffff:") ? remoteIp.slice(7) : remoteIp;
}

function getUserAgent(req) {
  return typeof req.get("user-agent") === "string"
    ? req.get("user-agent")
    : null;
}

function resolveDefaultPassword({ displayName }) {
  const username = typeof displayName === "string" ? displayName.trim() : "";
  if (!username) {
    return null;
  }
  return username;
}

router.get("/me", authenticate, async (req, res) => {
  const user = await db.findUserById(req.user.sub);
  if (!user) {
    return res.status(404).json({ message: "User not found" });
  }

  return res.json({ user: sanitizeUser(user) });
});

router.patch("/me/profile", authenticate, async (req, res) => {
  const displayName =
    typeof req.body?.displayName === "string" ? req.body.displayName.trim() : "";

  if (!displayName) {
    return res.status(400).json({
      error: "Display name is required.",
    });
  }

  const updatedUser = await db.updateUserProfile({
    userId: req.user.sub,
    email: null,
    displayName,
  });
  if (!updatedUser) {
    return res.status(404).json({ error: "User not found" });
  }

  await db.createAuditLog({
    userId: req.user.sub,
    eventType: "users_self_profile_updated",
    ipAddress: getClientIp(req),
    userAgent: getUserAgent(req),
    metadata: {
      actorUserId: req.user.sub,
      targetUserId: req.user.sub,
      displayName,
    },
  });

  return res.json({
    user: sanitizeUser(updatedUser),
    message: "Profile updated successfully.",
  });
});

router.get(
  "/",
  authenticate,
  requirePermission("users", "read"),
  async (req, res) => {
    const scope = resolvePermissionScope(req, "users", "read");
    const includeAll = canScopeReadAll(scope);
    const limit = Number.parseInt(String(req.query.limit ?? "100"), 10);

    const users = await db.listUsers({
      viewerUserId: req.user.sub,
      includeAll,
      limit: Number.isNaN(limit) ? 100 : limit,
    });

    return res.json({ users: users.map(sanitizeUser), scope });
  },
);

router.get(
  "/dashboard",
  authenticate,
  requirePermission("dashboard", "view"),
  async (req, res) => {
    const user = await db.findUserById(req.user.sub);
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    return res.json({
      message: "Dashboard access granted",
      requestedBy: sanitizeUser(user),
    });
  },
);

router.post("/actions/execute", authenticate, async (req, res) => {
  const resource = String(req.body?.resource ?? "")
    .trim()
    .toLowerCase();
  const action = String(req.body?.action ?? "")
    .trim()
    .toLowerCase();
  const actionKey = `${resource}:${action}`;

  if (!resource || !action || !validDashboardActionKeys.has(actionKey)) {
    return res.status(400).json({
      error: "Invalid action. Provide a valid resource/action pair.",
    });
  }

  const scope = resolvePermissionScope(req, resource, action);
  if (scope === "none") {
    return res
      .status(403)
      .json({ error: "Forbidden: Missing required permission" });
  }

  const log = await db.createAuditLog({
    userId: req.user.sub,
    eventType: "users_action_executed",
    ipAddress: getClientIp(req),
    userAgent: getUserAgent(req),
    metadata: {
      role: req.user.role,
      actorUserId: req.user.sub,
      scope,
      resource,
      action,
      actionKey,
    },
  });

  return res.status(200).json({
    message: `Action "${actionKey}" executed with "${scope}" scope.`,
    event: log,
  });
});

router.get("/logs/role-scoped", authenticate, async (req, res) => {
  const viewer = await db.findUserById(req.user.sub);
  if (!viewer) {
    return res.status(404).json({ error: "User not found" });
  }

  const role = String(viewer.role ?? "")
    .trim()
    .toLowerCase();
  if (role !== ROLE_NAMES.ADMIN && role !== ROLE_NAMES.MANAGER) {
    return res.status(403).json({
      error: "Forbidden: role does not have access to logs.",
    });
  }

  const includeAll = role === ROLE_NAMES.ADMIN;
  const limit = Number.parseInt(String(req.query.limit ?? "20"), 10);
  const normalizedLimit = Number.isNaN(limit) ? 20 : limit;

  const logs = await db.listAuditLogs({
    viewerUserId: req.user.sub,
    includeAll,
    limit: normalizedLimit,
  });

  await db.createAuditLog({
    userId: req.user.sub,
    eventType: "audit_logs_viewed",
    ipAddress: getClientIp(req),
    userAgent: getUserAgent(req),
    metadata: {
      actorUserId: req.user.sub,
      role,
      visibility: includeAll ? "all" : "own",
      limit: normalizedLimit,
    },
  });

  return res.json({
    logs,
    visibility: includeAll ? "all" : "own",
  });
});

router.get(
  "/logs",
  authenticate,
  requirePermission("audit_logs", "view"),
  async (req, res) => {
    const scope = resolvePermissionScope(req, "audit_logs", "view");
    const includeAll = scope === "full";
    const limit = Number.parseInt(String(req.query.limit ?? "20"), 10);

    const logs = await db.listAuditLogs({
      viewerUserId: req.user.sub,
      includeAll,
      limit: Number.isNaN(limit) ? 20 : limit,
    });

    return res.json({ logs, scope });
  },
);

router.get(
  "/actions/history",
  authenticate,
  requirePermission("audit_logs", "view"),
  async (req, res) => {
    const scope = resolvePermissionScope(req, "audit_logs", "view");
    const includeAll = scope === "full";
    const limit = Number.parseInt(String(req.query.limit ?? "20"), 10);

    const logs = await db.listAuditLogs({
      viewerUserId: req.user.sub,
      includeAll,
      limit: Number.isNaN(limit) ? 20 : limit,
    });

    return res.json({ logs, scope });
  },
);

router.get(
  "/admin/dashboard",
  authenticate,
  authorizeRole(ROLE_NAMES.ADMIN),
  async (req, res) => {
    const user = await db.findUserById(req.user.sub);
    return res.json({
      message: "Welcome to the admin dashboard!",
      requestedBy: sanitizeUser(user ?? req.user),
    });
  },
);

router.get(
  "/manager/dashboard",
  authenticate,
  authorizeRole([ROLE_NAMES.ADMIN, ROLE_NAMES.MANAGER]),
  async (req, res) => {
    const user = await db.findUserById(req.user.sub);
    return res.json({
      message: "Welcome to the manager dashboard!",
      requestedBy: sanitizeUser(user ?? req.user),
    });
  },
);

router.get(
  "/mod/dashboard",
  authenticate,
  authorizeRole([ROLE_NAMES.ADMIN, ROLE_NAMES.MANAGER]),
  async (req, res) => {
    const user = await db.findUserById(req.user.sub);
    return res.json({
      message: "Welcome to the manager dashboard!",
      requestedBy: sanitizeUser(user ?? req.user),
    });
  },
);

router.get(
  "/roles",
  authenticate,
  authorizeRole(ROLE_NAMES.ADMIN),
  async (req, res) => {
    const roles = await db.listRoles();
    return res.json({ roles });
  },
);

router.patch(
  "/:userId/role",
  authenticate,
  authorizeRole(ROLE_NAMES.ADMIN),
  async (req, res) => {
    const { userId } = req.params;
    const requestedRole = String(req.body?.role ?? "")
      .trim()
      .toLowerCase();

    const normalizedRole = normalizedRoleAlias.get(requestedRole);
    if (!normalizedRole) {
      return res.status(400).json({
        error:
          "Invalid role. Allowed values: admin, manager, user, guest (or menager alias).",
      });
    }

    const updatedUser = await db.updateUserRole({
      userId,
      roleName: normalizedRole,
    });
    if (!updatedUser) {
      return res.status(404).json({ error: "User not found" });
    }

    await db.createAuditLog({
      userId: req.user.sub,
      eventType: "users_role_updated",
      ipAddress: getClientIp(req),
      userAgent: getUserAgent(req),
      metadata: {
        actorUserId: req.user.sub,
        targetUserId: userId,
        role: normalizedRole,
      },
    });

    return res.json({ user: sanitizeUser(updatedUser) });
  },
);

router.post(
  "/:userId/password/reset",
  authenticate,
  authorizeRole(ROLE_NAMES.ADMIN),
  async (req, res) => {
    const { userId } = req.params;
    const targetUser = await db.findUserById(userId);
    if (!targetUser) {
      return res.status(404).json({ error: "User not found" });
    }

    const defaultPassword = resolveDefaultPassword({
      displayName: targetUser.displayName,
    });
    if (!defaultPassword) {
      return res.status(400).json({
        error:
          "Target user does not have a username (displayName). Cannot generate default password.",
      });
    }

    const passwordHash = await bcrypt.hash(defaultPassword, 12);
    const updated = await db.updateUserPasswordHash({
      userId: targetUser.id,
      passwordHash,
    });
    if (!updated) {
      return res.status(500).json({ error: "Failed to reset password." });
    }

    await db.createAuditLog({
      userId: req.user.sub,
      eventType: "users_password_reset",
      ipAddress: getClientIp(req),
      userAgent: getUserAgent(req),
      metadata: {
        actorUserId: req.user.sub,
        targetUserId: targetUser.id,
        passwordStrategy: "default_password_equals_username",
      },
    });

    return res.json({
      userId: targetUser.id,
      defaultPassword,
      message: "Password reset to default (username).",
    });
  },
);

router.post(
  "/",
  authenticate,
  requirePermission("users", "create"),
  async (req, res) => {
    const scope = resolvePermissionScope(req, "users", "create");
    if (scope === "none") {
      return res
        .status(403)
        .json({ error: "Forbidden: Missing required permission" });
    }

    const email =
      typeof req.body?.email === "string" ? req.body.email.trim() : "";
    const displayName =
      typeof req.body?.displayName === "string"
        ? req.body.displayName.trim()
        : "";
    const requestedRole = String(req.body?.role ?? "")
      .trim()
      .toLowerCase();

    if (!email || !displayName) {
      return res.status(400).json({
        error: "Email and username (displayName) are required.",
      });
    }

    const defaultPassword = resolveDefaultPassword({ displayName });
    if (!defaultPassword) {
      return res.status(400).json({
        error: "Username is required to generate default password.",
      });
    }
    if (defaultPassword.length < 6) {
      return res.status(400).json({
        error:
          "Username must be at least 6 characters because default password equals username.",
      });
    }

    let roleName = ROLE_NAMES.USER;
    if (requestedRole) {
      if (resolvePermissionScope(req, "roles", "manage") === "none") {
        return res.status(403).json({
          error: "Forbidden: Missing roles:manage permission for role override.",
        });
      }
      const normalizedRole = normalizedRoleAlias.get(requestedRole);
      if (!normalizedRole) {
        return res.status(400).json({
          error:
            "Invalid role. Allowed values: admin, manager, user, guest (or menager alias).",
        });
      }
      roleName = normalizedRole;
    }

    const existingUser = await db.findUserByEmail(email);
    if (existingUser) {
      return res.status(409).json({ error: "Email already exists." });
    }

    const passwordHash = await bcrypt.hash(defaultPassword, 12);
    const createdUser = await db.createUserWithPassword({
      email,
      displayName,
      passwordHash,
      roleName,
    });
    if (!createdUser) {
      return res.status(500).json({ error: "Failed to create DB user." });
    }

    await db.createAuditLog({
      userId: req.user.sub,
      eventType: "users_created",
      ipAddress: getClientIp(req),
      userAgent: getUserAgent(req),
      metadata: {
        actorUserId: req.user.sub,
        targetUserId: createdUser.id,
        role: createdUser.role,
        email: createdUser.email,
        passwordStrategy: "default_password_equals_username",
      },
    });

    return res.status(201).json({
      user: sanitizeUser(createdUser),
      defaultPassword,
      message: "User created. Default password is the username.",
    });
  },
);

router.patch(
  "/:userId",
  authenticate,
  requirePermission("users", "edit"),
  async (req, res) => {
    const { userId } = req.params;
    const scope = resolvePermissionScope(req, "users", "edit");
    if (
      !canAccessUserByScope({
        scope,
        actorUserId: req.user.sub,
        targetUserId: userId,
      })
    ) {
      return res
        .status(403)
        .json({ error: "Forbidden: Scope does not allow this user update." });
    }

    const email =
      typeof req.body?.email === "string" ? req.body.email.trim() : null;
    const displayName =
      typeof req.body?.displayName === "string"
        ? req.body.displayName.trim()
        : null;

    if (email === null && displayName === null) {
      return res.status(400).json({
        error: "Provide at least one field to update: email or displayName.",
      });
    }

    const updatedUser = await db.updateUserProfile({
      userId,
      email,
      displayName,
    });
    if (!updatedUser) {
      return res.status(404).json({ error: "User not found" });
    }

    await db.createAuditLog({
      userId: req.user.sub,
      eventType: "users_updated",
      ipAddress: getClientIp(req),
      userAgent: getUserAgent(req),
      metadata: {
        actorUserId: req.user.sub,
        targetUserId: userId,
        email,
        displayName,
      },
    });

    return res.json({ user: sanitizeUser(updatedUser) });
  },
);

router.delete(
  "/:userId",
  authenticate,
  requirePermission("users", "delete"),
  async (req, res) => {
    const { userId } = req.params;
    const scope = resolvePermissionScope(req, "users", "delete");
    if (
      !canAccessUserByScope({
        scope,
        actorUserId: req.user.sub,
        targetUserId: userId,
      })
    ) {
      return res
        .status(403)
        .json({ error: "Forbidden: Scope does not allow this user deletion." });
    }

    const deletedUserId = await db.deleteUserById({ userId });
    if (!deletedUserId) {
      return res.status(404).json({ error: "User not found" });
    }

    await db.createAuditLog({
      userId: req.user.sub,
      eventType: "users_deleted",
      ipAddress: getClientIp(req),
      userAgent: getUserAgent(req),
      metadata: {
        actorUserId: req.user.sub,
        targetUserId: deletedUserId,
      },
    });

    return res.json({ deleted: true, userId: deletedUserId });
  },
);

export default router;
