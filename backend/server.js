const path = require("path");
require("dotenv").config({ path: path.join(__dirname, ".env") });
const express = require("express");
const cors = require("cors");

const app = express();
const PORT = process.env.PORT || 5001;

// ─── Middleware ──────────────────────────────────────────────────────────────
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve uploaded files statically
app.use("/uploads", express.static(path.join(__dirname, "uploads")));

// ─── Routes ──────────────────────────────────────────────────────────────────
const authRoutes         = require("./routes/auth");
const usersRoutes        = require("./routes/users");
const patientRoutes      = require("./routes/patients");
const analysisRoutes     = require("./routes/analysis");
const prescriptionRoutes = require("./routes/prescriptions");
const notificationRoutes = require("./routes/notifications");
const medicalRoutes      = require("./routes/medical");
const adminRoutes        = require("./routes/admin");
const advertisementRoutes = require("./routes/advertisements");
const consultationRoutes = require("./routes/consultations");
const subscriptionRoutes = require("./routes/subscriptions");
const medicalAssistantRoutes = require("./routes/medicalAssistant");
const upload             = require("./config/multer");
const verifyToken        = require("./middleware/verifyToken");

app.use("/api/auth",          authRoutes);
app.use("/api/users",         usersRoutes);
app.use("/api/patients",      patientRoutes);
app.use("/api/analysis",      analysisRoutes);
app.use("/api/prescriptions", prescriptionRoutes);
app.use("/api/notifications", notificationRoutes);
app.use("/api/medical",      medicalRoutes);
app.use("/api/admin",        adminRoutes);
app.use("/api/advertisements", advertisementRoutes);
app.use("/api/consultations", consultationRoutes);
app.use("/api/subscriptions", subscriptionRoutes);
app.use("/api/medical-assistant", medicalAssistantRoutes);

// General file upload endpoint — POST /api/upload
app.post("/api/upload", verifyToken, upload.single("file"), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ message: "No file uploaded." });
  }
  const fileUrl = upload.getFileUrl(req.file);
  return res.status(200).json({
    message: "File uploaded successfully.",
    file_url: fileUrl,
  });
});

// ─── Health check ────────────────────────────────────────────────────────────
app.get("/", (req, res) => {
  res.json({ message: "Medical API is running." });
});

// ─── 404 handler ─────────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ message: "Route not found." });
});

// ─── Global error handler ────────────────────────────────────────────────────
app.use((err, req, res, next) => {
  console.error("Unhandled error:", err.message);
  res.status(err.status || 500).json({ message: err.message || "Internal server error." });
});

// ─── Start server ─────────────────────────────────────────────────────────────
const HOST = process.env.HOST || "0.0.0.0";
app.listen(PORT, HOST, () => {
  console.log(`Server running on http://${HOST === "0.0.0.0" ? "localhost" : HOST}:${PORT}`);
});