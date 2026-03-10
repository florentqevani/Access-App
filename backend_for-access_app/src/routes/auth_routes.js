import { Router } from "express";
import {
  exchangeFirebaseToken,
  refresh,
  revoke,
  logoutAll,
  getSessions,
} from "../controllers/auth_controller.js";
import authenticate from "../middleware/auth_middleware.js";

const router = Router();

router.post("/exchange", exchangeFirebaseToken);
router.post("/refresh", refresh);
router.post("/revoke", revoke);

router.post("/logout-all", authenticate, logoutAll);
router.get("/sessions", authenticate, getSessions);

export default router;
