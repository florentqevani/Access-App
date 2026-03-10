import { verifyAccessToken } from "../data/tokens.js";

const authenticate = (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader) {
    return res.status(401).json({ error: "Authorization header missing" });
  }

  const token = authHeader.startsWith("Bearer ")
    ? authHeader.split(" ")[1]
    : authHeader;

  try {
    const decoded = verifyAccessToken(token);
    if (decoded.type !== "access") {
      return res.status(401).json({ error: "Invalid token type" });
    }
    req.user = decoded;
    return next();
  } catch (error) {
    return res.status(401).json({ error: "Invalid or expired token" });
  }
};

export default authenticate;
