import { Pool } from "pg";

const DATABASE_URL =
  process.env.DATABASE_URL ||
  "postgres://access:access123@localhost:5432/access_app";

export const pgPool = new Pool({
  connectionString: DATABASE_URL,
});

export async function initPostgres() {
  await pgPool.query("SELECT 1");
}
