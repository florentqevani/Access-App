import "dotenv/config";
import express from "express";
import cors from "cors";
import authRoutes from "./routes/auth_routes.js";
import userRoutes from "./routes/users_route.js";
import { initPostgres } from "./config/postgres.js";
import { initRedis, redisClient } from "./config/redis.js";
import { runMigrations } from "./db/migrate.js";
import { db } from "./data/store.js";

const app = express();
const port = process.env.PORT || 3000;

app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(cors());

app.get("/", (req, res) => {
  res.json({ message: "backend-for-access-app is running" });
});

app.get("/health", async (req, res) => {
  try {
    await db.purgeExpiredTokens();
    const redisOk = await redisClient.ping();
    return res.status(200).json({ ok: true, redis: redisOk });
  } catch (error) {
    return res.status(500).json({ ok: false, error: "health-check-failed" });
  }
});

app.use("/", authRoutes);
app.use("/auth", authRoutes);
app.use("/api", authRoutes);
app.use("/api/auth", authRoutes);
app.use("/v1", authRoutes);
app.use("/v1/auth", authRoutes);
app.use("/users", userRoutes);

async function bootstrap() {
  await initPostgres();
  await runMigrations();
  await initRedis();

  app.listen(port, () => {
    console.log(`Server is running on http://localhost:${port}`);
  });
}

bootstrap().catch((error) => {
  console.error("Failed to start server:", error);
  process.exit(1);
});
