import { pgPool } from "../config/postgres.js";

export async function runMigrations() {
  await pgPool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id UUID PRIMARY KEY,
      firebase_uid TEXT NOT NULL UNIQUE,
      email TEXT,
      display_name TEXT,
      role TEXT NOT NULL DEFAULT 'user',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await pgPool.query(`
    CREATE TABLE IF NOT EXISTS refresh_tokens (
      token_hash TEXT PRIMARY KEY,
      session_id UUID NOT NULL UNIQUE,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      expires_at TIMESTAMPTZ NOT NULL,
      revoked_at TIMESTAMPTZ
    );
  `);

  await pgPool.query(`
    CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id
      ON refresh_tokens (user_id);
  `);

  await pgPool.query(`
    CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires_at
      ON refresh_tokens (expires_at);
  `);
}
