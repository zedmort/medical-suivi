const express = require("express");
const router = express.Router();
const verifyToken = require("../middleware/verifyToken");
const {
  getPrice,
  createPaidConsultation,
  getMyConsultations,
  getDoctorConsultations,
  updateConsultationStatus,
} = require("../controllers/consultationController");

router.get("/price", verifyToken, getPrice);
router.post("/symptoms/pay", verifyToken, createPaidConsultation);
router.get("/mine", verifyToken, getMyConsultations);
router.get("/doctor", verifyToken, getDoctorConsultations);
router.patch("/doctor/:id/status", verifyToken, updateConsultationStatus);

module.exports = router;
