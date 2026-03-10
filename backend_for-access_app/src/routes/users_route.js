import { Router } from "express";
import authenticate from "../middleware/auth_middleware.js";
import authorizeRole from "../middleware/role_middleware.js";
import { db } from "../data/store.js";
import { sanitizeUser } from "../data/tokens.js";

const router = Router();

router.get("/me", authenticate, async (req, res) => {
  const user = await db.findUserById(req.user.sub);
  if (!user) {
    return res.status(404).json({ message: "User not found" });
  }

  return res.json({ user: sanitizeUser(user) });
});

router.get(
  "/admin/dashboard",
  authenticate,
  authorizeRole("admin"),
  async (req, res) => {
    const user = await db.findUserById(req.user.sub);
    return res.json({
      message: "Welcome to the admin dashboard!",
      requestedBy: sanitizeUser(user ?? req.user),
    });
  },
);

router.get(
  "/mod/dashboard",
  authenticate,
  authorizeRole("moderator"),
  async (req, res) => {
    const user = await db.findUserById(req.user.sub);
    return res.json({
      message: "Welcome to the moderator dashboard!",
      requestedBy: sanitizeUser(user ?? req.user),
    });
  },
);

export default router;
