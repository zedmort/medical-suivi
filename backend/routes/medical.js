const express = require("express");
const router = express.Router();
const { getMedicalTaxonomy } = require("../controllers/userController");

router.get("/taxonomy", getMedicalTaxonomy);

module.exports = router;
