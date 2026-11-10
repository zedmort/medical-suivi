const express = require("express");
const router = express.Router();
const db = require("../config/db");
const verifyToken = require("../middleware/verifyToken");

router.get("/", verifyToken, async (req, res) => {
  const placement = String(req.query.placement || "dashboard");
  const allowedPlacements = [
    "dashboard",
    `${req.user.role}_dashboard`,
  ];
  if (!allowedPlacements.includes(placement)) {
    return res.status(400).json({ message: "Invalid advertisement placement." });
  }
  try {
    const [rows] = await db.execute(
      `SELECT id, title, description, image_url, destination_url, placement
       FROM advertisements
       WHERE is_active = 1
         AND placement IN ('dashboard', ?)
         AND (starts_at IS NULL OR starts_at <= UTC_TIMESTAMP())
         AND (expires_at IS NULL OR expires_at > UTC_TIMESTAMP())
       ORDER BY created_at DESC
       LIMIT 5`,
      [`${req.user.role}_dashboard`],
    );
    return res.status(200).json({ advertisements: rows });
  } catch (err) {
    console.error("Get active advertisements error:", err);
    return res.status(500).json({ message: "Server error." });
  }
});

const track = (field) => async (req, res) => {
  const id = Number.parseInt(req.params.id, 10);
  if (!Number.isInteger(id) || id <= 0) {
    return res.status(400).json({ message: "Invalid advertisement id." });
  }
  try {
    const [result] = await db.execute(
      `UPDATE advertisements SET ${field} = ${field} + 1
       WHERE id = ? AND is_active = 1
         AND (starts_at IS NULL OR starts_at <= UTC_TIMESTAMP())
         AND (expires_at IS NULL OR expires_at > UTC_TIMESTAMP())`,
      [id],
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Advertisement is not active." });
    }
    return res.status(200).json({ message: "Advertisement event recorded." });
  } catch (err) {
    console.error("Track advertisement event error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

router.post("/:id/impression", verifyToken, track("impressions"));
router.post("/:id/click", verifyToken, track("clicks"));

module.exports = router;
