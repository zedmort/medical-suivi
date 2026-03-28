const express = require("express");
const router = express.Router();
const verifyToken = require("../middleware/verifyToken");
const db = require("../config/db");

// GET /api/users/me  — returns the authenticated user's profile
router.get("/me", verifyToken, async (req, res) => {
  try {
    const [rows] = await db.execute(
      "SELECT id, name, email, role, specialty, created_at FROM users WHERE id = ?",
      [req.user.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ message: "User not found." });
    }

    return res.status(200).json({ user: rows[0] });
  } catch (err) {
    console.error("Get /me error:", err);
    return res.status(500).json({ message: "Server error." });
  }
});

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
