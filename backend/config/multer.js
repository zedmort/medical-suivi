const multer = require("multer");
const path = require("path");
const fs = require("fs");
const { CloudinaryStorage } = require("multer-storage-cloudinary");
const cloudinary = require("cloudinary").v2;

const hasCloudinaryConfig =
  !!process.env.CLOUDINARY_CLOUD_NAME &&
  !!process.env.CLOUDINARY_API_KEY &&
  !!process.env.CLOUDINARY_API_SECRET;

if (hasCloudinaryConfig) {
  cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET,
    secure: true,
  });
}

const uploadDir = path.join(__dirname, "../uploads");
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const localStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const unique = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
    cb(null, `${unique}${path.extname(file.originalname)}`);
  },
});

const cloudinaryStorage = hasCloudinaryConfig
  ? new CloudinaryStorage({
      cloudinary,
      params: async (req, file) => ({
        folder: process.env.CLOUDINARY_FOLDER || "medical-suivi",
        resource_type: "auto",
        public_id: `${Date.now()}-${Math.round(Math.random() * 1e9)}`,
        allowed_formats: ["jpg", "jpeg", "png", "pdf"],
      }),
    })
  : null;

const fileFilter = (req, file, cb) => {
  const allowed = /jpeg|jpg|png|pdf/;
  const ext = path.extname(file.originalname).toLowerCase();
  if (allowed.test(ext)) {
    cb(null, true);
  } else {
    cb(new Error("Only JPEG, PNG, and PDF files are allowed."));
  }
};

const upload = multer({
  storage: cloudinaryStorage || localStorage,
  fileFilter,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
});

const getFileUrl = (file) => {
  if (!file) return null;
  if (typeof file.path === "string" && /^https?:\/\//i.test(file.path)) {
    return file.path;
  }
  if (typeof file.filename === "string" && file.filename.length > 0) {
    return `/uploads/${file.filename}`;
  }
  return null;
};

upload.getFileUrl = getFileUrl;

module.exports = upload;
