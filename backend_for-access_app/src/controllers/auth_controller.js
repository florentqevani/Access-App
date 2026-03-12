import { v4 as uuidv4 } from "uuid";
import bcrypt from "bcryptjs";
import { db } from "../data/store.js";
import {
  issueAccessToken,
  issueRefreshToken,
  verifyRefreshToken,
  getAccessTokenExpiryDate,
  getRefreshTokenExpiryDate,
  sanitizeUser,
} from "../data/tokens.js";
import { hashToken } from "../utils/crypto.js";

function isValidEmail(email) {
  if (typeof email !== "string") {
    return false;
  }
  const normalized = email.trim();
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalized);
}

export async function signup(req, res) {
  try {
    const name = typeof req.body?.name === "string" ? req.body.name.trim() : "";
    const email = typeof req.body?.email === "string" ? req.body.email.trim().toLowerCase() : "";
    const password = typeof req.body?.password === "string" ? req.body.password : "";

    if (!email || !password) {
      return res.status(400).json({ error: "Email and password are required." });
    }
    if (!isValidEmail(email)) {
      return res.status(400).json({ error: "Email format is invalid." });
    }
    if (password.length < 6) {
      return res
        .status(400)
        .json({ error: "Password must be at least 6 characters." });
    }

    const existingUser = await db.findUserByEmail(email);
    if (existingUser) {
      return res.status(409).json({ error: "Email already exists." });
    }

    const passwordHash = await bcrypt.hash(password, 12);
    const user = await db.createUserWithPassword({
      email,
      displayName: name || null,
      passwordHash,
    });
    if (!user) {
      return res.status(500).json({ error: "Failed to create user." });
    }

    const tokens = await issueTokens(user);
    return res.status(201).json(tokens);
  } catch (error) {
    return res.status(500).json({ error: "Sign up failed." });
  }
}

export async function login(req, res) {
  try {
    const email = typeof req.body?.email === "string" ? req.body.email.trim().toLowerCase() : "";
    const password = typeof req.body?.password === "string" ? req.body.password : "";

    if (!email || !password) {
      return res.status(400).json({ error: "Email and password are required." });
    }

    const credentials = await db.findUserCredentialsByEmail(email);
    if (!credentials?.passwordHash) {
      return res.status(401).json({ error: "Invalid email or password." });
    }

    const passwordMatches = await bcrypt.compare(password, credentials.passwordHash);
    if (!passwordMatches) {
      return res.status(401).json({ error: "Invalid email or password." });
    }

    const user = await db.findUserById(credentials.userId);
    if (!user) {
      return res.status(401).json({ error: "Invalid email or password." });
    }

    const tokens = await issueTokens(user);
    return res.status(200).json(tokens);
  } catch (error) {
    return res.status(500).json({ error: "Login failed." });
  }
}


export async function refresh(req, res) {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) {
      return res.status(400).json({ error: "Refresh token is required" });
    }

    const tokenHash = hashToken(refreshToken);
    let decodedRefresh;
    try {
      decodedRefresh = verifyRefreshToken(refreshToken);
    } catch (err) {
      return res.status(403).json({ error: "Invalid refresh token" });
    }

    if (decodedRefresh.type !== "refresh") {
      return res.status(403).json({ error: "Invalid refresh token type" });
    }

    const storedToken = await db.findRefreshToken(tokenHash);
    if (!storedToken || storedToken.revokedAt || storedToken.expiresAt < new Date()) {
      return res.status(403).json({ error: "Refresh token is invalid or revoked" });
    }
    if (storedToken.sessionId !== decodedRefresh.sid) {
      return res.status(403).json({ error: "Refresh token session mismatch" });
    }
    if (storedToken.userId !== decodedRefresh.sub) {
      return res.status(403).json({ error: "Refresh token user mismatch" });
    }

    const user = await db.findUserById(decodedRefresh.sub);
    if (!user) {
      return res.status(403).json({ error: "User not found" });
    }

    await db.revokeRefreshToken(tokenHash);
    const tokens = await issueTokens(user);
    return res.status(200).json(tokens);
  } catch (err) {
    return res.status(500).json({ error: "Token refresh failed" });
  }
}

export async function revoke(req, res) {
  const { refreshToken } = req.body;
  if (!refreshToken) {
    return res.status(400).json({ error: "Refresh token is required" });
  }

  const revoked = await db.revokeRefreshToken(hashToken(refreshToken));
  return res.status(200).json({ revoked });
}

export async function logoutAll(req, res) {
  await db.revokeAllUserTokens(req.user.sub);
  return res.status(200).json({ message: "Logged out from all devices" });
}

export async function getSessions(req, res) {
  const sessions = await db.getUserTokens(req.user.sub);
  return res.status(200).json({ sessions });
}

export async function changePassword(req, res) {
  try {
    const currentPassword =
      typeof req.body?.currentPassword === "string" ? req.body.currentPassword : "";
    const newPassword =
      typeof req.body?.newPassword === "string" ? req.body.newPassword : "";

    if (!currentPassword || !newPassword) {
      return res.status(400).json({
        error: "Current password and new password are required.",
      });
    }
    if (newPassword.length < 6) {
      return res.status(400).json({
        error: "New password must be at least 6 characters.",
      });
    }
    if (currentPassword === newPassword) {
      return res.status(400).json({
        error: "New password must be different from current password.",
      });
    }

    const userId = req.user.sub;
    const passwordHash = await db.getUserPasswordHash(userId);
    if (!passwordHash) {
      return res.status(400).json({
        error: "Password is not set for this account.",
      });
    }

    const currentMatches = await bcrypt.compare(currentPassword, passwordHash);
    if (!currentMatches) {
      return res.status(401).json({ error: "Current password is incorrect." });
    }

    const nextPasswordHash = await bcrypt.hash(newPassword, 12);
    const updated = await db.updateUserPasswordHash({
      userId,
      passwordHash: nextPasswordHash,
    });
    if (!updated) {
      return res.status(500).json({ error: "Failed to update password." });
    }

    await db.createAuditLog({
      userId,
      eventType: "users_self_password_changed",
      metadata: {
        actorUserId: userId,
      },
    });

    await db.revokeAllUserTokens(userId);
    return res.status(200).json({
      message: "Password updated successfully. Please sign in again.",
    });
  } catch (error) {
    return res.status(500).json({ error: "Failed to change password." });
  }
}

async function issueTokens(user) {
  const sessionId = uuidv4();
  const accessToken = issueAccessToken({
    id: user.id,
    email: user.email,
    role: user.role,
  });
  const refreshToken = issueRefreshToken({
    userId: user.id,
    sessionId,
  });
  const refreshTokenHash = hashToken(refreshToken);

  const accessTokenExpiresAt = getAccessTokenExpiryDate();
  const refreshTokenExpiresAt = getRefreshTokenExpiryDate();

  await db.saveRefreshToken(refreshTokenHash, {
    userId: user.id,
    sessionId,
    expiresAt: refreshTokenExpiresAt,
  });

  return {
    accessToken,
    refreshToken,
    accessTokenExpiresAt: accessTokenExpiresAt.toISOString(),
    refreshTokenExpiresAt: refreshTokenExpiresAt.toISOString(),
    expiresIn: Math.floor((accessTokenExpiresAt.getTime() - Date.now()) / 1000),
    user: sanitizeUser(user),
  };
}
