require("dotenv").config();
const express = require("express");
const cors = require("cors");
const path = require("path");

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
const upload             = require("./config/multer");
const verifyToken        = require("./middleware/verifyToken");

app.use("/api/auth",          authRoutes);
app.use("/api/users",         usersRoutes);
app.use("/api/patients",      patientRoutes);
app.use("/api/analysis",      analysisRoutes);
app.use("/api/prescriptions", prescriptionRoutes);
app.use("/api/notifications", notificationRoutes);

// General file upload endpoint — POST /api/upload
app.post("/api/upload", verifyToken, upload.single("file"), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ message: "No file uploaded." });
  }
  return res.status(200).json({
    message: "File uploaded successfully.",
    file_url: `/uploads/${req.file.filename}`,
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
app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});