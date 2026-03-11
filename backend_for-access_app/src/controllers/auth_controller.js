import { v4 as uuidv4 } from "uuid";
import { db } from "../data/store.js";
import {
  issueAccessToken,
  issueRefreshToken,
  verifyRefreshToken,
  getAccessTokenExpiryDate,
  getRefreshTokenExpiryDate,
  sanitizeUser,
} from "../data/tokens.js";
import { getFirebaseAuth, hasFirebaseAdminCredentials } from "../config/firebase.js";
import { hashToken } from "../utils/crypto.js";


export async function exchangeFirebaseToken(req, res) {
  try {
    const { idToken } = req.body;
    if (!idToken) {
      return res.status(400).json({ error: "idToken is required" });
    }

    const decoded = await getFirebaseAuth().verifyIdToken(
      idToken,
      hasFirebaseAdminCredentials(),
    );
    const user = await db.upsertFirebaseUser({
      firebaseUid: decoded.uid,
      email: decoded.email ?? null,
      displayName: decoded.name ?? null,
    });

    const tokens = await issueTokens(user);
    return res.status(200).json(tokens);
  } catch (error) {
    return res.status(401).json({ error: "Invalid Firebase ID token" });
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

async function issueTokens(user) {
  const sessionId = uuidv4();
  const accessToken = issueAccessToken({
    id: user.id,
    email: user.email,
    role: user.role,
    firebaseUid: user.firebaseUid,
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
