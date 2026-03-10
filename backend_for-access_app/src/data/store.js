import { pgPool } from "../config/postgres.js";
import { redisClient } from "../config/redis.js";
import { v4 as uuidv4 } from "uuid";

const userCacheKey = (userId) => `cache:user:${userId}`;
const refreshSessionKey = (tokenHash) => `session:refresh:${tokenHash}`;
const userSessionSetKey = (userId) => `session:user:${userId}`;

const SESSION_CACHE_TTL_SECONDS = 60 * 60 * 24 * 7;
const USER_CACHE_TTL_SECONDS = 60 * 10;

function toUser(row) {
  if (!row) return null;
  return {
    id: row.id,
    firebaseUid: row.firebase_uid,
    email: row.email,
    displayName: row.display_name,
    role: row.role,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export const db = {
  async upsertFirebaseUser({ firebaseUid, email, displayName }) {
    const id = uuidv4();
    const result = await pgPool.query(
      `
      INSERT INTO users (id, firebase_uid, email, display_name)
      VALUES ($1, $2, $3, $4)
      ON CONFLICT (firebase_uid)
      DO UPDATE SET
        email = EXCLUDED.email,
        display_name = EXCLUDED.display_name,
        updated_at = NOW()
      RETURNING *;
      `,
      [id, firebaseUid, email ?? null, displayName ?? null],
    );

    const user = toUser(result.rows[0]);
    if (user) {
      await redisClient.setEx(
        userCacheKey(user.id),
        USER_CACHE_TTL_SECONDS,
        JSON.stringify(user),
      );
    }
    return user;
  },

  async findUserById(id) {
    const cached = await redisClient.get(userCacheKey(id));
    if (cached) {
      return JSON.parse(cached);
    }

    const result = await pgPool.query("SELECT * FROM users WHERE id = $1", [id]);
    const user = toUser(result.rows[0]);
    if (user) {
      await redisClient.setEx(
        userCacheKey(user.id),
        USER_CACHE_TTL_SECONDS,
        JSON.stringify(user),
      );
    }
    return user;
  },

  async saveRefreshToken(tokenHash, metadata) {
    await pgPool.query(
      `
      INSERT INTO refresh_tokens (token_hash, session_id, user_id, expires_at)
      VALUES ($1, $2, $3, $4)
      `,
      [tokenHash, metadata.sessionId, metadata.userId, metadata.expiresAt],
    );

    const ttl = Math.max(
      Math.floor((new Date(metadata.expiresAt).getTime() - Date.now()) / 1000),
      1,
    );

    await redisClient.setEx(
      refreshSessionKey(tokenHash),
      ttl,
      JSON.stringify({
        userId: metadata.userId,
        sessionId: metadata.sessionId,
        expiresAt: metadata.expiresAt,
      }),
    );
    await redisClient.sAdd(userSessionSetKey(metadata.userId), tokenHash);
    await redisClient.expire(userSessionSetKey(metadata.userId), ttl);
  },

  async findRefreshToken(tokenHash) {
    const cached = await redisClient.get(refreshSessionKey(tokenHash));
    if (cached) {
      const parsed = JSON.parse(cached);
      return {
        tokenHash,
        sessionId: parsed.sessionId,
        userId: parsed.userId,
        expiresAt: new Date(parsed.expiresAt),
        revokedAt: null,
      };
    }

    const result = await pgPool.query(
      `
      SELECT token_hash, session_id, user_id, expires_at, revoked_at
      FROM refresh_tokens
      WHERE token_hash = $1
      `,
      [tokenHash],
    );

    if (result.rows.length === 0) {
      return null;
    }

    const row = result.rows[0];
    if (!row.revoked_at && row.expires_at > new Date()) {
      const ttl = Math.max(
        Math.floor((row.expires_at.getTime() - Date.now()) / 1000),
        1,
      );
      await redisClient.setEx(
        refreshSessionKey(tokenHash),
        ttl,
        JSON.stringify({
          userId: row.user_id,
          sessionId: row.session_id,
          expiresAt: row.expires_at.toISOString(),
        }),
      );
    }

    return {
      tokenHash: row.token_hash,
      sessionId: row.session_id,
      userId: row.user_id,
      expiresAt: row.expires_at,
      revokedAt: row.revoked_at,
    };
  },

  async revokeRefreshToken(tokenHash) {
    const result = await pgPool.query(
      `
      UPDATE refresh_tokens
      SET revoked_at = NOW()
      WHERE token_hash = $1 AND revoked_at IS NULL
      RETURNING token_hash, user_id;
      `,
      [tokenHash],
    );

    await redisClient.del(refreshSessionKey(tokenHash));
    if (result.rows.length > 0) {
      await redisClient.sRem(userSessionSetKey(result.rows[0].user_id), tokenHash);
      return true;
    }
    return false;
  },

  async revokeAllUserTokens(userId) {
    const updated = await pgPool.query(
      `
      UPDATE refresh_tokens
      SET revoked_at = NOW()
      WHERE user_id = $1 AND revoked_at IS NULL
      RETURNING token_hash
      `,
      [userId],
    );

    const hashes = updated.rows.map((row) => row.token_hash);
    if (hashes.length > 0) {
      await redisClient.del(...hashes.map((hash) => refreshSessionKey(hash)));
    }
    await redisClient.del(userSessionSetKey(userId));
  },

  async getUserTokens(userId) {
    const result = await pgPool.query(
      `
      SELECT session_id, created_at, expires_at, revoked_at
      FROM refresh_tokens
      WHERE user_id = $1
      ORDER BY created_at DESC
      `,
      [userId],
    );

    return result.rows.map((row) => ({
      sessionId: row.session_id,
      createdAt: row.created_at,
      expiresAt: row.expires_at,
      revokedAt: row.revoked_at,
    }));
  },

  async purgeExpiredTokens() {
    const result = await pgPool.query(
      `
      DELETE FROM refresh_tokens
      WHERE expires_at < NOW()
      `,
    );
    return result.rowCount ?? 0;
  },
};
