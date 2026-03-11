import { verifyAccessToken } from "../data/tokens.js";
import { db } from "../data/store.js";

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

    return next();
  } catch (error) {
    return res.status(401).json({ error: "Invalid or expired token" });
  }
};

export default authenticate;
