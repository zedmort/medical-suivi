const db = require("../config/db");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const {
  isValidRegistrationSpecialty,
  isKnownDisease,
} = require("../config/medicalTaxonomy");
require("dotenv").config();

const SALT_ROUNDS = 10;

const isValidDateOfBirth = (value) => {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return false;
  }
  const date = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(date.getTime()) &&
    date.toISOString().slice(0, 10) === value &&
    date < new Date();
};

const calculateAge = (dateOfBirth) => {
  const dob = new Date(`${dateOfBirth}T00:00:00Z`);
  const now = new Date();
  let age = now.getUTCFullYear() - dob.getUTCFullYear();
  if (
    now.getUTCMonth() < dob.getUTCMonth() ||
    (now.getUTCMonth() === dob.getUTCMonth() && now.getUTCDate() < dob.getUTCDate())
  ) {
    age--;
  }
  return age;
};

// POST /api/auth/register
const register = async (req, res) => {
  const {
    email,
    password,
    role,
    firstname,
    lastname,
    date_of_birth,
    address,
    sex,
    phone,
    doctor_type,
    specialties,
    professional_info,
    conditions,
  } = req.body;

  if (!email || !password || !role || !firstname || !lastname ||
      !date_of_birth || !address || !phone) {
    return res.status(400).json({ message: "All fields are required." });
  }

  const validRoles = ["doctor", "patient", "labo", "pharmacy"];
  if (!validRoles.includes(role)) {
    return res.status(400).json({ message: `Role must be one of: ${validRoles.join(", ")}` });
  }

  if (!isValidDateOfBirth(date_of_birth)) {
    return res.status(400).json({ message: "A valid date of birth is required." });
  }

  if (typeof email !== "string" || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) {
    return res.status(400).json({ message: "A valid email address is required." });
  }

  const normalizedSpecialties = Array.isArray(specialties)
    ? [...new Set(specialties.map((value) => String(value).trim().toLowerCase()))]
    : [];
  if (role === "doctor") {
    if (!["general_practitioner", "specialist"].includes(doctor_type)) {
      return res.status(400).json({ message: "Doctor type must be general_practitioner or specialist." });
    }
    if (
      normalizedSpecialties.length > 1 ||
      normalizedSpecialties.some((specialty) => !isValidRegistrationSpecialty(specialty)) ||
      (doctor_type === "specialist" && normalizedSpecialties.length === 0) ||
      (doctor_type === "general_practitioner" && normalizedSpecialties.length > 0)
    ) {
      return res.status(400).json({
        message: "Specialists must select either diabetology or thyroid diseases; general practitioners must not select a specialty.",
      });
    }
  }

  const normalizedConditions = role === "patient" && Array.isArray(conditions)
    ? [...new Set(conditions.map((value) => String(value).trim()))]
    : [];
  if (role === "patient") {
    if (!sex || !["M", "F"].includes(sex) ||
        normalizedConditions.length === 0 ||
        normalizedConditions.some((condition) => !isKnownDisease(condition))) {
      return res.status(400).json({
        message: "A valid sex and at least one recognized medical condition are required for patient registration.",
      });
    }
    if (calculateAge(date_of_birth) < 0 || calculateAge(date_of_birth) > 125) {
      return res.status(400).json({ message: "Date of birth is outside the supported age range." });
    }
  }

  const firstName = firstname.toString().trim();
  const lastName = lastname.toString().trim();
  const fullName = `${firstName} ${lastName}`.trim();
  const normalizedEmail = email.trim().toLowerCase();
  const patientAge = role === "patient" ? calculateAge(date_of_birth) : null;
  let connection;
  let transactionStarted = false;
  try {
    connection = await db.getConnection();
    await connection.beginTransaction();
    transactionStarted = true;
    const [existing] = await connection.execute("SELECT id FROM users WHERE email = ?", [normalizedEmail]);
    if (existing.length > 0) {
      await connection.rollback();
      transactionStarted = false;
      return res.status(409).json({ message: "Email already registered." });
    }

    const password_hash = await bcrypt.hash(password, SALT_ROUNDS);

    const [result] = await connection.execute(
      `INSERT INTO users
         (name, email, password_hash, role, specialty, firstname, lastname,
          date_of_birth, address, phone, doctor_type, professional_info)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        fullName,
        normalizedEmail,
        password_hash,
        role,
        normalizedSpecialties[0] || null,
        firstName,
        lastName,
        date_of_birth,
        address.toString().trim(),
        phone.toString().trim(),
        role === "doctor" ? doctor_type : null,
        role === "doctor" && professional_info
          ? professional_info.toString().trim()
          : null,
      ]
    );

    if (role === "doctor") {
      for (const specialty of normalizedSpecialties) {
        const [specialtyResult] = await connection.execute(
          `INSERT INTO doctor_specialties (doctor_id, specialty_id)
           SELECT ?, id FROM specialties WHERE slug = ?`,
          [result.insertId, specialty],
        );
        if (specialtyResult.affectedRows === 0) {
          throw new Error(`Unknown specialty: ${specialty}`);
        }
      }
    }

    if (role === "patient") {
      const [patientResult] = await connection.execute(
        `INSERT INTO patients
           (user_id, doctor_id, firstname, lastname, address, age, date_of_birth, sex, disease, phone)
         VALUES (?, NULL, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          result.insertId,
          firstName,
          lastName,
          address.toString().trim(),
          patientAge,
          date_of_birth,
          sex,
          normalizedConditions[0],
          phone.toString().trim(),
        ]
      );
      for (const condition of normalizedConditions) {
        const [conditionResult] = await connection.execute(
          `INSERT INTO patient_conditions (patient_id, condition_id)
           SELECT ?, id FROM medical_conditions WHERE name = ?`,
          [patientResult.insertId, condition],
        );
        if (conditionResult.affectedRows === 0) {
          throw new Error(`Unknown medical condition: ${condition}`);
        }
      }
    }

    await connection.commit();
    transactionStarted = false;
    return res.status(201).json({
      message: "User registered successfully.",
      userId: result.insertId,
    });
  } catch (err) {
    if (connection && transactionStarted) await connection.rollback();
    if (err.code === "ER_DUP_ENTRY") {
      return res.status(409).json({ message: "Email already registered." });
    }
    console.error("Register error:", err);
    return res.status(500).json({
      message: "Server error during registration.",
    });
  } finally {
    connection?.release();
  }
};

// POST /api/auth/login
const login = async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ message: "Email and password are required." });
  }

  try {
    if (typeof email !== "string") {
      return res.status(400).json({ message: "A valid email address is required." });
    }
    const normalizedEmail = email.trim().toLowerCase();
    const [rows] = await db.execute(
      "SELECT * FROM users WHERE email = ?",
      [normalizedEmail],
    );
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
    return res.status(500).json({
      message: `Server error during login: ${err && err.message ? err.message : "unknown error"}`,
      error: err && err.code ? err.code : undefined,
    });
  }
};

module.exports = { register, login };
