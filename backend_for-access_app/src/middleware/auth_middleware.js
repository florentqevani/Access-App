import { verifyAccessToken } from "../data/tokens.js";
import { db } from "../data/store.js";

const REDACTED_KEYS = new Set([
  "password",
  "currentpassword",
  "newpassword",
  "confirmpassword",
  "idtoken",
  "refreshtoken",
  "authorization",
  "token",
]);

function redactValue(value, depth = 0) {
  if (value == null) {
    return value;
  }

  if (depth > 3) {
    return "[truncated]";
  }

  if (Array.isArray(value)) {
    return value.slice(0, 20).map((item) => redactValue(item, depth + 1));
  }

  if (typeof value === "object") {
    const redacted = {};
    for (const [key, nestedValue] of Object.entries(value)) {
      if (REDACTED_KEYS.has(String(key).toLowerCase())) {
        redacted[key] = "[redacted]";
      } else {
        redacted[key] = redactValue(nestedValue, depth + 1);
      }
    }
    return redacted;
  }

  if (typeof value === "string") {
    if (value.length > 300) {
      return `${value.slice(0, 300)}...`;
    }
    return value;
  }

  return value;
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

function attachActivityLogger(req, res) {
  if (res.locals.activityLoggerAttached) {
    return;
  }
  res.locals.activityLoggerAttached = true;

  const startedAt = Date.now();
  res.on("finish", () => {
    const userId = req.user?.sub;
    if (!userId) {
      return;
    }

    const metadata = {
      type: "http_request",
      method: req.method,
      path: req.path,
      route: req.originalUrl,
      statusCode: res.statusCode,
      durationMs: Date.now() - startedAt,
      role: req.user?.role ?? null,
      query: redactValue(req.query ?? {}),
      body: redactValue(req.body ?? {}),
    };

    db.createAuditLog({
      userId,
      eventType: "app_request",
      ipAddress: getClientIp(req),
      userAgent:
        typeof req.get("user-agent") === "string" ? req.get("user-agent") : null,
      metadata,
    }).catch((error) => {
      console.error("Failed to persist activity log:", error);
    });
  });
}

const authenticate = async (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader) {
    return res.status(401).json({ error: "Authorization header missing" });
  }

  const token = authHeader.startsWith("Bearer ")
    ? authHeader.split(" ")[1]
    : authHeader;

  try {
    const decoded = verifyAccessToken(token);
    if (decoded.type !== "access") {
      return res.status(401).json({ error: "Invalid token type" });
    }

    const user = await db.findUserById(decoded.sub);
    if (!user) {
      return res.status(401).json({ error: "User not found" });
    }

    req.user = {
      ...decoded,
      email: user.email,
      role: user.role,
      permissions: user.permissionCodes,
      permissionScopes: Array.isArray(user.permissions)
        ? user.permissions.reduce((acc, permission) => {
            const key = `${permission.resource}:${permission.action}`;
            acc[key] = permission.scope;
            return acc;
          }, {})
        : {},
    };

    attachActivityLogger(req, res);
    return next();
  } catch (error) {
    return res.status(401).json({ error: "Invalid or expired token" });
  }
};

export default authenticate;
