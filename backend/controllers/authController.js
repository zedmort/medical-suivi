const db = require("../config/db");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const {
  isValidSpecialty,
  isKnownDisease,
} = require("../config/medicalTaxonomy");
require("dotenv").config();

const SALT_ROUNDS = 10;

// POST /api/auth/register
const register = async (req, res) => {
  const {
    name,
    email,
    password,
    role,
    specialty,
    firstname,
    lastname,
    age,
    address,
    sex,
    disease,
    phone,
  } = req.body;

  if (!name || !email || !password || !role) {
    return res.status(400).json({ message: "All fields are required." });
  }

  const validRoles = ["doctor", "patient", "labo", "pharmacy"];
  if (!validRoles.includes(role)) {
    return res.status(400).json({ message: `Role must be one of: ${validRoles.join(", ")}` });
  }

  if (role === "doctor") {
    if (!specialty || !isValidSpecialty(specialty)) {
      return res.status(400).json({ message: "Valid doctor specialty is required." });
    }
  }

  if (role === "patient") {
    if (!firstname || !lastname || !address || !age || !sex || !disease) {
      return res.status(400).json({
        message: "firstname, lastname, age, address, sex and disease are required for patient registration.",
      });
    }
    if (!["M", "F"].includes(sex)) {
      return res.status(400).json({ message: "sex must be M or F." });
    }
    const parsedAge = parseInt(age, 10);
    if (Number.isNaN(parsedAge) || parsedAge <= 0) {
      return res.status(400).json({ message: "age must be a valid number." });
    }
    if (!isKnownDisease(disease)) {
      return res.status(400).json({ message: "Please choose a disease from the medical list." });
    }
  }

  try {
    const [existing] = await db.execute("SELECT id FROM users WHERE email = ?", [email]);
    if (existing.length > 0) {
      return res.status(409).json({ message: "Email already registered." });
    }

    const password_hash = await bcrypt.hash(password, SALT_ROUNDS);

    const fullName = role === "patient"
      ? `${firstname}`.trim() + " " + `${lastname}`.trim()
      : name;

    const [result] = await db.execute(
      "INSERT INTO users (name, email, password_hash, role, specialty) VALUES (?, ?, ?, ?, ?)",
      [fullName, email, password_hash, role, role === "doctor" ? specialty.toString().trim().toLowerCase() : null]
    );

    if (role === "patient") {
      await db.execute(
        `INSERT INTO patients (user_id, doctor_id, firstname, lastname, address, age, sex, disease, phone)
         VALUES (?, NULL, ?, ?, ?, ?, ?, ?, ?)`,
        [
          result.insertId,
          firstname.toString().trim(),
          lastname.toString().trim(),
          address.toString().trim(),
          parseInt(age, 10),
          sex,
          disease.toString().trim(),
          phone || null,
        ]
      );
    }

    return res.status(201).json({
      message: "User registered successfully.",
      userId: result.insertId,
    });
  } catch (err) {
    console.error("Register error:", err);
    return res.status(500).json({ message: "Server error during registration." });
  }
};

// POST /api/auth/login
const login = async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ message: "Email and password are required." });
  }

  try {
    const [rows] = await db.execute("SELECT * FROM users WHERE email = ?", [email]);
    if (rows.length === 0) {
      return res.status(401).json({ message: "Invalid credentials." });
    }

    const user = rows[0];
    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
      return res.status(401).json({ message: "Invalid credentials." });
    }

    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role, specialty: user.specialty || null },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || "24h" }
    );

    return res.status(200).json({
      message: "Login successful.",
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        specialty: user.specialty,
      },
    });
  } catch (err) {
    console.error("Login error:", err);
    return res.status(500).json({ message: "Server error during login." });
  }
};

module.exports = { register, login };
