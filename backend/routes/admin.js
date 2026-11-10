const express = require("express");
const router = express.Router();
const verifyToken = require("../middleware/verifyToken");
const requireRole = require("../middleware/requireRole");
const upload = require("../config/multer");
const {
  getSettings,
  uploadAdImage,
  updateConsultationPrice,
  listTransactions,
  listAds,
  saveAd,
  updateAdStatus,
  deleteAd,
  getConditionMappings,
  updateConditionMappings,
} = require("../controllers/adminController");

router.use(verifyToken, requireRole("admin"));

router.get("/settings", getSettings);
router.put("/settings/consultation-price", updateConsultationPrice);
router.get("/transactions", listTransactions);
router.get("/advertisements", listAds);
router.post("/advertisements/upload", upload.image.single("file"), uploadAdImage);
router.post("/advertisements", saveAd);
router.put("/advertisements/:id", saveAd);
router.patch("/advertisements/:id/status", updateAdStatus);
router.delete("/advertisements/:id", deleteAd);
router.get("/condition-mappings", getConditionMappings);
router.put("/condition-mappings/:id", updateConditionMappings);

module.exports = router;
