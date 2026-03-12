import { pgPool } from "../config/postgres.js";
import { redisClient } from "../config/redis.js";
import { v4 as uuidv4 } from "uuid";
import { ROLE_NAMES } from "../rbac/constants.js";

const userCacheKey = (userId) => `cache:v2:user:${userId}`;
const refreshSessionKey = (tokenHash) => `session:refresh:${tokenHash}`;
const userSessionSetKey = (userId) => `session:user:${userId}`;

const SESSION_CACHE_TTL_SECONDS = 60 * 60 * 24 * 7;
const USER_CACHE_TTL_SECONDS = 60 * 10;

const roleIdByNameCache = new Map();

const USER_SELECT_WITH_ROLE_AND_PERMISSIONS = `
  SELECT
    u.id,
    u.email,
    u.display_name,
    u.created_at,
    u.updated_at,
    r.id AS role_id,
    r.name AS role_name,
    COALESCE(
      json_agg(
        json_build_object(
          'resource', p.resource,
          'action', p.action,
          'scope', rp.scope
        )
        ORDER BY p.resource, p.action
      ) FILTER (WHERE p.id IS NOT NULL),
      '[]'::json
    ) AS permissions
  FROM users u
  JOIN roles r ON r.id = u.role_id
  LEFT JOIN role_permissions rp ON rp.role_id = r.id
  LEFT JOIN permissions p ON p.id = rp.permission_id
`;

function toUser(row) {
  if (!row) return null;

  const permissions = Array.isArray(row.permissions) ? row.permissions : [];
  const effectivePermissions = permissions.filter(
    (permission) => permission.scope !== "none",
  );

  return {
    id: row.id,
    email: row.email,
    displayName: row.display_name,
    roleId: row.role_id,
    role: row.role_name,
    permissions,
    permissionCodes: effectivePermissions.map(
      (permission) => `${permission.resource}:${permission.action}`,
    ),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

async function findUserByClause(whereClause, params) {
  const result = await pgPool.query(
    `
    ${USER_SELECT_WITH_ROLE_AND_PERMISSIONS}
    ${whereClause}
    GROUP BY u.id, r.id
    LIMIT 1;
    `,
    params,
  );

  return toUser(result.rows[0]);
}

async function listUsersByClause(whereClause, params, limit) {
  const result = await pgPool.query(
    `
    ${USER_SELECT_WITH_ROLE_AND_PERMISSIONS}
    ${whereClause}
    GROUP BY u.id, r.id
    ORDER BY u.created_at DESC
    LIMIT $${params.length + 1};
    `,
    [...params, limit],
  );

  return result.rows.map((row) => toUser(row)).filter(Boolean);
}

async function getRoleIdByName(roleName) {
  const normalizedRoleName = String(roleName || "").toLowerCase();
  if (roleIdByNameCache.has(normalizedRoleName)) {
    return roleIdByNameCache.get(normalizedRoleName);
  }

  const result = await pgPool.query("SELECT id FROM roles WHERE name = $1", [
    normalizedRoleName,
  ]);
  if (result.rows.length === 0) {
    return null;
  }

  const roleId = result.rows[0].id;
  roleIdByNameCache.set(normalizedRoleName, roleId);
  return roleId;
}

async function cacheUser(user) {
  if (!user) return;
  await redisClient.setEx(
    userCacheKey(user.id),
    USER_CACHE_TTL_SECONDS,
    JSON.stringify(user),
  );
}

export const db = {
  async findUserByEmail(email) {
    const normalizedEmail = String(email || "").trim().toLowerCase();
    if (!normalizedEmail) {
      return null;
    }

    return findUserByClause("WHERE lower(u.email) = $1", [normalizedEmail]);
  },

  async findUserCredentialsByEmail(email) {
    const normalizedEmail = String(email || "").trim().toLowerCase();
    if (!normalizedEmail) {
      return null;
    }

    const result = await pgPool.query(
      `
      SELECT id, password_hash
      FROM users
      WHERE lower(email) = $1
      LIMIT 1;
      `,
      [normalizedEmail],
    );

    if (result.rows.length === 0) {
      return null;
    }

    return {
      userId: result.rows[0].id,
      passwordHash: result.rows[0].password_hash,
    };
  },

  async getUserPasswordHash(userId) {
    const result = await pgPool.query(
      `
      SELECT password_hash
      FROM users
      WHERE id = $1
      LIMIT 1;
      `,
      [userId],
    );

    if (result.rows.length === 0) {
      return null;
    }
    return result.rows[0].password_hash;
  },

  async updateUserPasswordHash({ userId, passwordHash }) {
    const result = await pgPool.query(
      `
      UPDATE users
      SET password_hash = $1, updated_at = NOW()
      WHERE id = $2
      RETURNING id;
      `,
      [passwordHash, userId],
    );

    return result.rows.length > 0;
  },

  async createUserWithPassword({
    email,
    displayName,
    passwordHash,
    roleName = ROLE_NAMES.USER,
  }) {
    const normalizedEmail = String(email || "").trim().toLowerCase();
    if (!normalizedEmail) {
      throw new Error("Email is required.");
    }

    const roleId = await getRoleIdByName(roleName);
    if (!roleId) {
      throw new Error(`Role '${roleName}' was not found in database.`);
    }

    const userId = uuidv4();
    const result = await pgPool.query(
      `
      INSERT INTO users (id, email, display_name, password_hash, role_id)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING id;
      `,
      [userId, normalizedEmail, displayName ?? null, passwordHash, roleId],
    );

    const createdId = result.rows[0]?.id;
    if (!createdId) {
      return null;
    }

    await redisClient.del(userCacheKey(createdId));
    const user = await findUserByClause("WHERE u.id = $1", [createdId]);
    await cacheUser(user);
    return user;
  },

  async findUserById(id) {
    const cached = await redisClient.get(userCacheKey(id));
    if (cached) {
      return JSON.parse(cached);
    }

    const user = await findUserByClause("WHERE u.id = $1", [id]);
    await cacheUser(user);
    return user;
  },

  async listUsers({ viewerUserId, includeAll = false, limit = 100 }) {
    const normalizedLimit = Math.min(Math.max(Number(limit) || 100, 1), 500);

    if (includeAll) {
      return listUsersByClause("WHERE TRUE", [], normalizedLimit);
    }

    return listUsersByClause("WHERE u.id = $1", [viewerUserId], normalizedLimit);
  },

  async listRoles() {
    const result = await pgPool.query(
      `
      SELECT id, name, description, created_at
      FROM roles
      ORDER BY name ASC;
      `,
    );

    return result.rows.map((row) => ({
      id: row.id,
      name: row.name,
      description: row.description,
      createdAt: row.created_at,
    }));
  },

  async updateUserRole({ userId, roleName }) {
    const normalizedRoleName = String(roleName || "").trim().toLowerCase();
    const roleId = await getRoleIdByName(normalizedRoleName);
    if (!roleId) {
      return null;
    }

    const updated = await pgPool.query(
      `
      UPDATE users
      SET role_id = $1, updated_at = NOW()
      WHERE id = $2
      RETURNING id;
      `,
      [roleId, userId],
    );

    if (updated.rows.length === 0) {
      return null;
    }

    await redisClient.del(userCacheKey(userId));
    const user = await findUserByClause("WHERE u.id = $1", [userId]);
    await cacheUser(user);
    return user;
  },

  async updateUserProfile({ userId, email, displayName }) {
    const result = await pgPool.query(
      `
      UPDATE users
      SET email = COALESCE($1, email),
          display_name = COALESCE($2, display_name),
          updated_at = NOW()
      WHERE id = $3
      RETURNING id;
      `,
      [email, displayName, userId],
    );

    if (result.rows.length === 0) {
      return null;
    }

    await redisClient.del(userCacheKey(userId));
    const user = await findUserByClause("WHERE u.id = $1", [userId]);
    await cacheUser(user);
    return user;
  },

  async deleteUserById({ userId }) {
    const result = await pgPool.query(
      `
      DELETE FROM users
      WHERE id = $1
      RETURNING id;
      `,
      [userId],
    );

    if (result.rows.length === 0) {
      return null;
    }

    await redisClient.del(userCacheKey(userId));
    return result.rows[0].id;
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

  async createAuditLog({
    userId,
    eventType,
    ipAddress = null,
    userAgent = null,
    metadata = {},
  }) {
    const result = await pgPool.query(
      `
      INSERT INTO logs (
        id,
        user_id,
        event_type,
        ip_address,
        user_agent,
        metadata
      )
      VALUES ($1, $2, $3, $4, $5, $6::jsonb)
      RETURNING
        id,
        user_id,
        event_type,
        ip_address,
        user_agent,
        metadata,
        created_at;
      `,
      [
        uuidv4(),
        userId,
        eventType,
        ipAddress,
        userAgent,
        JSON.stringify(metadata ?? {}),
      ],
    );

    const row = result.rows[0];
    return {
      id: row.id,
      userId: row.user_id,
      eventType: row.event_type,
      ipAddress: row.ip_address,
      userAgent: row.user_agent,
      metadata: row.metadata,
      createdAt: row.created_at,
    };
  },

  async listAuditLogs({ viewerUserId, includeAll = false, limit = 20 }) {
    const normalizedLimit = Math.min(Math.max(Number(limit) || 20, 1), 100);

    const result = await pgPool.query(
      `
      SELECT
        l.id,
        l.user_id,
        l.event_type,
        l.ip_address::text AS ip_address,
        l.user_agent,
        l.metadata,
        l.created_at,
        u.email,
        u.display_name,
        r.name AS role
      FROM logs l
      JOIN users u ON u.id = l.user_id
      JOIN roles r ON r.id = u.role_id
      WHERE ($1::boolean = true OR l.user_id = $2)
      ORDER BY l.created_at DESC
      LIMIT $3;
      `,
      [includeAll, viewerUserId, normalizedLimit],
    );

    return result.rows.map((row) => ({
      id: row.id,
      userId: row.user_id,
      eventType: row.event_type,
      ipAddress: row.ip_address,
      userAgent: row.user_agent,
      metadata: row.metadata,
      createdAt: row.created_at,
      actor: {
        email: row.email,
        displayName: row.display_name,
        role: row.role,
      },
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
