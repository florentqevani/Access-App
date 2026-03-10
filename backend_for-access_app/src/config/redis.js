import { createClient } from "redis";

const REDIS_URL = process.env.REDIS_URL || "redis://localhost:6379";

export const redisClient = createClient({ url: REDIS_URL });

redisClient.on("error", (error) => {
  console.error("Redis error:", error.message);
});

export async function initRedis() {
  if (!redisClient.isOpen) {
    await redisClient.connect();
  }
  await redisClient.ping();
}
