const express = require("express");
const router = express.Router();
const verifyToken = require("../middleware/verifyToken");
const {
  createConversation,
  listConversations,
  getMessages,
  sendMessage,
  getDoctors,
  createConsultationRequest,
  getDoctorRequests,
  updateDoctorRequest,
} = require("../controllers/medicalAssistantController");

router.use(verifyToken);
router.get("/conversations", listConversations);
router.post("/conversations", createConversation);
router.get("/conversations/:id/messages", getMessages);
router.post("/conversations/:id/messages", sendMessage);
router.get("/doctors", getDoctors);
router.post("/conversations/:id/consultation-requests", createConsultationRequest);
router.get("/doctor/consultation-requests", getDoctorRequests);
router.patch("/doctor/consultation-requests/:id", updateDoctorRequest);

module.exports = router;
