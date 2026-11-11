const express = require("express");
const router = express.Router();
const verifyToken = require("../middleware/verifyToken");
const {
  getPlans,
  getMySubscription,
  activateDemoSubscription,
} = require("../controllers/subscriptionController");

router.get("/plans", verifyToken, getPlans);
router.get("/me", verifyToken, getMySubscription);
router.post("/activate-demo", verifyToken, activateDemoSubscription);

module.exports = router;
