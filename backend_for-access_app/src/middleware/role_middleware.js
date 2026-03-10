const requireRole = (allowedRoles = []) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const normalizedRoles = Array.isArray(allowedRoles)
      ? allowedRoles
      : [allowedRoles];

    if (!normalizedRoles.includes(req.user.role)) {
      return res
        .status(403)
        .json({ error: "Forbidden: Insufficient permissions" });
    }

    return next();
  };
};

export default requireRole;
