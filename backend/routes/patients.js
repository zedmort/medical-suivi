const express = require("express");
const router = express.Router();
const verifyToken = require("../middleware/verifyToken");
const {
	createPatient,
	getPatients,
	getAvailablePatients,
	getPatient,
	updatePatient,
	getMyOverview,
} = require("../controllers/patientController");

router.get("/me/overview", verifyToken, getMyOverview);
router.get("/available", verifyToken, getAvailablePatients);

router.post("/",     verifyToken, createPatient);
router.get("/",      verifyToken, getPatients);
router.get("/:id",   verifyToken, getPatient);
router.put("/:id",   verifyToken, updatePatient);

module.exports = router;
