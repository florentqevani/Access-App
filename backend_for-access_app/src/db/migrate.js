import { pgPool } from "../config/postgres.js";
import { v4 as uuidv4 } from "uuid";
import {
  RBAC_PERMISSIONS,
  ROLE_DESCRIPTIONS,
  ROLE_NAMES,
  ROLE_PERMISSION_SCOPES,
  PERMISSION_SCOPE,
  permissionKey,
} from "../rbac/constants.js";

export async function runMigrations() {
  const client = await pgPool.connect();
  try {
    await client.query("BEGIN");

    await client.query(`
      CREATE TABLE IF NOT EXISTS roles (
        id UUID PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `);

    await client.query(`
      CREATE TABLE IF NOT EXISTS permissions (
        id UUID PRIMARY KEY,
        resource TEXT NOT NULL,
        action TEXT NOT NULL,
        description TEXT,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        UNIQUE(resource, action)
      );
    `);

    await client.query(`
      CREATE TABLE IF NOT EXISTS role_permissions (
        role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
        permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
        scope TEXT NOT NULL CHECK (scope IN ('none', 'own', 'team', 'limited', 'full')),
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        PRIMARY KEY (role_id, permission_id)
      );
    `);

    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        id UUID PRIMARY KEY,
        firebase_uid TEXT NOT NULL UNIQUE,
        email TEXT,
        display_name TEXT,
        role_id UUID,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `);

    await client.query(`
      ALTER TABLE users
      ADD COLUMN IF NOT EXISTS role_id UUID;
    `);

    await seedRolesAndPermissions(client);
    await backfillUserRoles(client);
    await ensureUsersRoleConstraint(client);

    await client.query(`
      CREATE TABLE IF NOT EXISTS refresh_tokens (
        token_hash TEXT PRIMARY KEY,
        session_id UUID NOT NULL UNIQUE,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        expires_at TIMESTAMPTZ NOT NULL,
        revoked_at TIMESTAMPTZ
      );
    `);

    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id
        ON refresh_tokens (user_id);
    `);

    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires_at
        ON refresh_tokens (expires_at);
    `);

    await client.query(`
      CREATE TABLE IF NOT EXISTS logs (
        id UUID PRIMARY KEY,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        event_type VARCHAR(120) NOT NULL,
        ip_address INET,
        user_agent TEXT,
        metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `);

    await client.query(`
      ALTER TABLE logs
      ADD COLUMN IF NOT EXISTS ip_address INET;
    `);

    await client.query(`
      ALTER TABLE logs
      ADD COLUMN IF NOT EXISTS user_agent TEXT;
    `);

    await client.query(`
      ALTER TABLE logs
      ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;
    `);

    await client.query(`
      ALTER TABLE logs
      ALTER COLUMN event_type TYPE VARCHAR(120);
    `);

    await client.query(`
      ALTER TABLE logs
      DROP COLUMN IF EXISTS resource;
    `);

    await client.query(`
      ALTER TABLE logs
      DROP COLUMN IF EXISTS action;
    `);

    await client.query(`
      ALTER TABLE logs
      DROP COLUMN IF EXISTS scope;
    `);

    await client.query(`
      DO $$
      BEGIN
        IF EXISTS (
          SELECT 1
          FROM information_schema.tables
          WHERE table_schema = 'public'
            AND table_name = 'audit_logs'
        ) THEN
          ALTER TABLE audit_logs
          ADD COLUMN IF NOT EXISTS ip_address INET;

          ALTER TABLE audit_logs
          ADD COLUMN IF NOT EXISTS user_agent TEXT;

          ALTER TABLE audit_logs
          ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

          ALTER TABLE audit_logs
          ALTER COLUMN event_type TYPE VARCHAR(120);

          INSERT INTO logs (id, user_id, event_type, ip_address, user_agent, metadata, created_at)
          SELECT
            id,
            user_id,
            event_type,
            ip_address,
            user_agent,
            COALESCE(metadata, '{}'::jsonb),
            created_at
          FROM audit_logs
          ON CONFLICT (id) DO NOTHING;
        END IF;
      END $$;
    `);

    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_logs_user_id
        ON logs (user_id);
    `);

    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_logs_created_at
        ON logs (created_at DESC);
    `);

    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

async function seedRolesAndPermissions(client) {
  const roleNames = Object.values(ROLE_NAMES);
  const validPermissionKeys = RBAC_PERMISSIONS.map((permission) =>
    permissionKey(permission.resource, permission.action),
  );

  for (const roleName of roleNames) {
    await client.query(
      `
      INSERT INTO roles (id, name, description)
      VALUES ($1, $2, $3)
      ON CONFLICT (name)
      DO UPDATE SET description = EXCLUDED.description;
      `,
      [uuidv4(), roleName, ROLE_DESCRIPTIONS[roleName] ?? null],
    );
  }

  for (const permission of RBAC_PERMISSIONS) {
    await client.query(
      `
      INSERT INTO permissions (id, resource, action, description)
      VALUES ($1, $2, $3, $4)
      ON CONFLICT (resource, action)
      DO UPDATE SET description = EXCLUDED.description;
      `,
      [
        uuidv4(),
        permission.resource,
        permission.action,
        permission.description ?? null,
      ],
    );
  }

  await client.query(
    `
    DELETE FROM permissions
    WHERE (resource || ':' || action) <> ALL($1::text[]);
    `,
    [validPermissionKeys],
  );

  const roleRows = await client.query("SELECT id, name FROM roles;");
  const permissionRows = await client.query(
    "SELECT id, resource, action FROM permissions;",
  );

  const roleIdByName = new Map(roleRows.rows.map((row) => [row.name, row.id]));
  const permissionIdByKey = new Map(
    permissionRows.rows.map((row) => [
      permissionKey(row.resource, row.action),
      row.id,
    ]),
  );

  for (const roleName of roleNames) {
    const roleId = roleIdByName.get(roleName);
    if (!roleId) continue;

    const scopedPermissions = ROLE_PERMISSION_SCOPES[roleName] ?? {};
    for (const permission of RBAC_PERMISSIONS) {
      const key = permissionKey(permission.resource, permission.action);
      const permissionId = permissionIdByKey.get(key);
      if (!permissionId) continue;

      const scope = scopedPermissions[key] ?? PERMISSION_SCOPE.NONE;
      await client.query(
        `
        INSERT INTO role_permissions (role_id, permission_id, scope)
        VALUES ($1, $2, $3)
        ON CONFLICT (role_id, permission_id)
        DO UPDATE SET scope = EXCLUDED.scope;
        `,
        [roleId, permissionId, scope],
      );
    }
  }
}

async function backfillUserRoles(client) {
  await client.query(`
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'users'
          AND column_name = 'role'
      ) THEN
        EXECUTE $sql$
          UPDATE users u
          SET role_id = r.id
          FROM roles r
          WHERE u.role_id IS NULL
            AND r.name = CASE
              WHEN lower(coalesce(u.role, '')) = 'moderator' THEN 'manager'
              WHEN lower(coalesce(u.role, '')) IN ('admin', 'manager', 'user', 'guest') THEN lower(u.role)
              ELSE 'user'
            END
        $sql$;
      END IF;
    END $$;
  `);

  await client.query(
    `
    UPDATE users u
    SET role_id = r.id
    FROM roles r
    WHERE u.role_id IS NULL
      AND r.name = $1;
    `,
    [ROLE_NAMES.USER],
  );
}

async function ensureUsersRoleConstraint(client) {
  await client.query(`
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_users_role_id'
      ) THEN
        ALTER TABLE users
          ADD CONSTRAINT fk_users_role_id
          FOREIGN KEY (role_id)
          REFERENCES roles(id);
      END IF;
    END $$;
  `);

  await client.query(`
    ALTER TABLE users
    ALTER COLUMN role_id SET NOT NULL;
  `);
}
