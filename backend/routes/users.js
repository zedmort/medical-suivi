const express = require("express");
const router = express.Router();
const verifyToken = require("../middleware/verifyToken");
const db = require("../config/db");
const { getMe, updateMe, getDoctors } = require("../controllers/userController");

// GET /api/users/me  — returns the authenticated user's profile
router.get("/me", verifyToken, getMe);
router.put("/me", verifyToken, updateMe);
router.get("/doctors", verifyToken, getDoctors);

// GET /api/users?role=patient|doctor|labo|pharmacy  — list users by role (doctor only)
router.get("/", verifyToken, async (req, res) => {
  if (req.user.role !== "doctor" && req.user.role !== "pharmacy") {
    return res.status(403).json({ message: "Access denied." });
  }
  const { role } = req.query;
  try {
    let query = "SELECT id, name, email, role, specialty, created_at FROM users";
    const params = [];
    if (role) {
      query += " WHERE role = ?";
      params.push(role);
    }
    query += " ORDER BY name ASC";
    const [rows] = await db.execute(query, params);
    return res.status(200).json({ users: rows });
  } catch (err) {
    console.error("Get users error:", err);
    return res.status(500).json({ message: "Server error." });
  }
});

module.exports = router;
