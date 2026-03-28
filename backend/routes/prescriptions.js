const express = require("express");
const router = express.Router();
const verifyToken = require("../middleware/verifyToken");
const upload = require("../config/multer");
const {
  getPrescriptions,
  createPrescription,
  updateStatus,
} = require("../controllers/prescriptionController");

// GET /api/prescriptions  — pharmacy / patient / doctor views prescriptions
router.get("/", verifyToken, getPrescriptions);

// POST /api/prescriptions/create  — doctor creates a prescription (optional file)
router.post("/create", verifyToken, upload.single("file"), createPrescription);

// PATCH /api/prescriptions/:id/status  — pharmacy marks as dispensed
router.patch("/:id/status", verifyToken, updateStatus);

module.exports = router;
