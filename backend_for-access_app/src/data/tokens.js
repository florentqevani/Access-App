import jwt from "jsonwebtoken";

const { ACCESS_TOKEN_EXPIRY = "15m", REFRESH_TOKEN_EXPIRY = "7d" } =
  process.env;

const ACCESS_TOKEN_SECRET =
  process.env.ACCESS_TOKEN_SECRET || "dev-access-token-secret";
const REFRESH_TOKEN_SECRET =
  process.env.REFRESH_TOKEN_SECRET || "dev-refresh-token-secret";

export function issueAccessToken(user) {
  return jwt.sign(
    {
      sub: user.id,
      email: user.email,
      role: user.role,
      permissions: Array.isArray(user.permissionCodes)
        ? user.permissionCodes
        : [],
      firebaseUid: user.firebaseUid,
      type: "access",
    },
    ACCESS_TOKEN_SECRET,
    { expiresIn: ACCESS_TOKEN_EXPIRY },
  );
}

export function issueRefreshToken({ userId, sessionId }) {
  return jwt.sign(
    { sub: userId, sid: sessionId, type: "refresh" },
    REFRESH_TOKEN_SECRET,
    { expiresIn: REFRESH_TOKEN_EXPIRY },
  );
}

export function verifyAccessToken(token) {
  return jwt.verify(token, ACCESS_TOKEN_SECRET);
}

export function verifyRefreshToken(token) {
  return jwt.verify(token, REFRESH_TOKEN_SECRET);
}

export function getExpiryDate(tokenDuration) {
  const units = {
    s: 1000,
    m: 60 * 1000,
    h: 60 * 60 * 1000,
    d: 24 * 60 * 60 * 1000,
  };

  const match = tokenDuration.match(/(\d+)([smhd])/);
  if (!match) {
    throw new Error("Invalid token duration format");
  }

  const [, value, unit] = match;
  return new Date(Date.now() + parseInt(value, 10) * units[unit]);
}

export function sanitizeUser(user) {
  const { password, ...sanitized } = user;
  return sanitized;
}

export function getAccessTokenExpiryDate() {
  return getExpiryDate(ACCESS_TOKEN_EXPIRY);
}

export function getRefreshTokenExpiryDate() {
  return getExpiryDate(REFRESH_TOKEN_EXPIRY);
}
