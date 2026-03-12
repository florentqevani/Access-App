import { Router } from "express";
import {
  signup,
  login,
  refresh,
  revoke,
  logoutAll,
  getSessions,
  changePassword,
} from "../controllers/auth_controller.js";
import authenticate from "../middleware/auth_middleware.js";

const router = Router();

router.post("/signup", signup);
router.post("/register", signup);
router.post("/sign-up", signup);
router.post("/login", login);
router.post("/signin", login);
router.post("/sign-in", login);
router.post("/refresh", refresh);
router.post("/revoke", revoke);
router.patch("/change-password", authenticate, changePassword);

router.post("/logout-all", authenticate, logoutAll);
router.get("/sessions", authenticate, getSessions);

export default router;
