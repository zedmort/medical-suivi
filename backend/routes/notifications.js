const express = require("express");
const router = express.Router();
const verifyToken = require("../middleware/verifyToken");
const { getNotifications, markRead, markAllRead } = require("../controllers/notificationController");

router.get("/",               verifyToken, getNotifications);
router.patch("/read-all",     verifyToken, markAllRead);
router.patch("/:id/read",     verifyToken, markRead);

module.exports = router;
