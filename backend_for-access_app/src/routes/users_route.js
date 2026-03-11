import { Router } from "express";
import authenticate from "../middleware/auth_middleware.js";
import authorizeRole from "../middleware/role_middleware.js";
import requirePermission, {
  resolvePermissionScope,
} from "../middleware/permission_middleware.js";
import { db } from "../data/store.js";
import { sanitizeUser } from "../data/tokens.js";
import { getFirebaseAuth, hasFirebaseAdminCredentials } from "../config/firebase.js";
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

function firebaseClientApiKey() {
  const key =
    process.env.FIREBASE_CLIENT_API_KEY || process.env.FIREBASE_WEB_API_KEY;
  if (typeof key !== "string") {
    return null;
  }
  const trimmed = key.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function mapIdentityToolkitError(errorMessage, fallbackMessage) {
  if (typeof errorMessage !== "string") {
    return { status: 500, error: fallbackMessage };
  }

  if (errorMessage === "EMAIL_EXISTS") {
    return { status: 409, error: "Email already exists." };
  }
  if (errorMessage.startsWith("WEAK_PASSWORD")) {
    return {
      status: 400,
      error:
        "Username must be at least 6 characters because default password equals username.",
    };
  }

  return { status: 500, error: fallbackMessage };
}

async function parseIdentityToolkitJson(response) {
  try {
    return await response.json();
  } catch (_) {
    return {};
  }
}

async function createFirebaseUserWithClientApiKey({
  apiKey,
  email,
  password,
  displayName,
}) {
  const signUpResponse = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email,
        password,
        returnSecureToken: true,
      }),
    },
  );

  const signUpPayload = await parseIdentityToolkitJson(signUpResponse);
  if (!signUpResponse.ok) {
    const mapped = mapIdentityToolkitError(
      signUpPayload?.error?.message,
      "Failed to create Firebase user.",
    );
    throw mapped;
  }

  const uid = signUpPayload.localId;
  const idToken = signUpPayload.idToken;
  if (!uid || !idToken) {
    throw { status: 500, error: "Failed to create Firebase user." };
  }

  const updateResponse = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:update?key=${apiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        idToken,
        displayName,
        returnSecureToken: true,
      }),
    },
  );
  if (!updateResponse.ok) {
    throw { status: 500, error: "Failed to set Firebase username." };
  }

  return { uid };
}

router.get("/me", authenticate, async (req, res) => {
  const user = await db.findUserById(req.user.sub);
  if (!user) {
    return res.status(404).json({ message: "User not found" });
  }

  return res.json({ user: sanitizeUser(user) });
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

    if (!hasFirebaseAdminCredentials()) {
      return res.status(503).json({
        error:
          "Password reset requires Firebase Admin credentials. Configure GOOGLE_APPLICATION_CREDENTIALS or FIREBASE_SERVICE_ACCOUNT_JSON.",
      });
    }

    try {
      await getFirebaseAuth().updateUser(targetUser.firebaseUid, {
        password: defaultPassword,
      });
    } catch (error) {
      if (error?.code === "auth/user-not-found") {
        await getFirebaseAuth().createUser({
          uid: targetUser.firebaseUid,
          email: targetUser.email ?? undefined,
          displayName: targetUser.displayName ?? undefined,
          password: defaultPassword,
        });
      } else {
        return res.status(500).json({ error: "Failed to reset password." });
      }
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

    let firebaseUid;
    if (hasFirebaseAdminCredentials()) {
      try {
        const firebaseUser = await getFirebaseAuth().createUser({
          email,
          password: defaultPassword,
          displayName,
        });
        firebaseUid = firebaseUser.uid;
      } catch (error) {
        if (error?.code === "auth/email-already-exists") {
          return res.status(409).json({ error: "Email already exists." });
        }
        if (
          error?.code === "auth/weak-password" ||
          error?.code === "auth/invalid-password"
        ) {
          return res.status(400).json({
            error:
              "Username must be at least 6 characters because default password equals username.",
          });
        }
        return res.status(500).json({
          error: "Failed to create Firebase user.",
        });
      }
    } else {
      const apiKey = firebaseClientApiKey();
      if (!apiKey) {
        return res.status(503).json({
          error:
            "User creation needs Firebase credentials. Set GOOGLE_APPLICATION_CREDENTIALS/FIREBASE_SERVICE_ACCOUNT_JSON or FIREBASE_CLIENT_API_KEY.",
        });
      }
      try {
        const fallbackUser = await createFirebaseUserWithClientApiKey({
          apiKey,
          email,
          password: defaultPassword,
          displayName,
        });
        firebaseUid = fallbackUser.uid;
      } catch (error) {
        const status =
          typeof error?.status === "number" ? error.status : 500;
        const message =
          typeof error?.error === "string"
            ? error.error
            : "Failed to create Firebase user.";
        return res.status(status).json({ error: message });
      }
    }

    const createdUser = await db.upsertFirebaseUser({
      firebaseUid,
      email,
      displayName,
    });
    if (!createdUser) {
      return res.status(500).json({ error: "Failed to create DB user." });
    }

    let effectiveUser = createdUser;
    if (roleName !== ROLE_NAMES.USER) {
      const roleUpdatedUser = await db.updateUserRole({
        userId: createdUser.id,
        roleName,
      });
      if (roleUpdatedUser) {
        effectiveUser = roleUpdatedUser;
      }
    }

    await db.createAuditLog({
      userId: req.user.sub,
      eventType: "users_created",
      ipAddress: getClientIp(req),
      userAgent: getUserAgent(req),
      metadata: {
        actorUserId: req.user.sub,
        targetUserId: effectiveUser.id,
        role: effectiveUser.role,
        email: effectiveUser.email,
        passwordStrategy: "default_password_equals_username",
      },
    });

    return res.status(201).json({
      user: sanitizeUser(effectiveUser),
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
