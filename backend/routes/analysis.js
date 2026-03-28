const express = require("express");
const router = express.Router();
const verifyToken = require("../middleware/verifyToken");
const upload = require("../config/multer");
const {
  createRequest,
  getPatientAnalysis,
  uploadResult,
  getMyRequests,
} = require("../controllers/analysisController");

// POST /api/analysis/create  — doctor creates an analysis request
router.post("/create", verifyToken, upload.single("file"), createRequest);

// GET /api/analysis/patient/:patientId  — doctor views patient analyses
router.get("/patient/:patientId", verifyToken, getPatientAnalysis);

// POST /api/analysis/upload-result  — labo uploads result file
router.post("/upload-result", verifyToken, upload.single("file"), uploadResult);

// GET /api/analysis/my-requests  — returns requests relevant to the current user's role
router.get("/my-requests", verifyToken, getMyRequests);

module.exports = router;
