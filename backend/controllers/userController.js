const db = require("../config/db");
const {
  getSpecialties,
  isValidSpecialty,
  isKnownDisease,
} = require("../config/medicalTaxonomy");
const { findPatientForUser } = require("../utils/patientIdentity");

const isValidDateOfBirth = (value) => {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return false;
  }
  const date = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(date.getTime()) &&
    date.toISOString().slice(0, 10) === value &&
    date < new Date();
};

const calculateAge = (value) => {
  const birth = new Date(`${value}T00:00:00Z`);
  const today = new Date();
  let age = today.getUTCFullYear() - birth.getUTCFullYear();
  if (
    today.getUTCMonth() < birth.getUTCMonth() ||
    (today.getUTCMonth() === birth.getUTCMonth() &&
      today.getUTCDate() < birth.getUTCDate())
  ) {
    age--;
  }
  return age;
};

const getMe = async (req, res) => {
  try {
    const [rows] = await db.execute(
      `SELECT id, name, email, role, specialty, firstname, lastname,
              date_of_birth, address, phone, doctor_type, professional_info, created_at
       FROM users WHERE id = ?`,
      [req.user.id],
    );
    if (rows.length === 0) {
      return res.status(404).json({ message: "User not found." });
    }

    const user = rows[0];
    if (user.role === "doctor") {
      const [specialties] = await db.execute(
        `SELECT s.slug, s.name
         FROM doctor_specialties ds
         JOIN specialties s ON s.id = ds.specialty_id
         WHERE ds.doctor_id = ?
         ORDER BY s.name`,
        [user.id],
      );
      user.specialties = specialties.map((item) => item.slug);
      if (user.specialties.length === 0 && user.specialty) {
        user.specialties = [user.specialty];
      }
    } else if (user.role === "patient") {
      const identity = await findPatientForUser(user);
      let patients = [];
      if (identity) {
        [patients] = await db.execute(
          `SELECT p.id, p.sex, p.disease, p.next_analysis_date, p.doctor_id,
                  d.name AS doctor_name
           FROM patients p
           LEFT JOIN users d ON d.id = p.doctor_id AND d.role = 'doctor'
           WHERE p.id = ? LIMIT 1`,
          [identity.id],
        );
      }
      if (patients[0]) {
        const [conditions] = await db.execute(
          `SELECT c.id, c.name
           FROM patient_conditions pc
           JOIN medical_conditions c ON c.id = pc.condition_id
           WHERE pc.patient_id = ?
           ORDER BY c.name`,
          [patients[0].id],
        );
        user.patient = {
          ...patients[0],
          conditions: conditions.map((condition) => condition.name),
        };
      }
    }

    return res.status(200).json({ user });
  } catch (err) {
    console.error("Get /me error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

const updateMe = async (req, res) => {
  const { firstname, lastname, date_of_birth, address, phone } = req.body;
  if (
    !firstname?.toString().trim() ||
    !lastname?.toString().trim() ||
    !isValidDateOfBirth(date_of_birth) ||
    !address?.toString().trim() ||
    !phone?.toString().trim()
  ) {
    return res.status(400).json({
      message: "First name, last name, date of birth, address, and phone are required.",
    });
  }

  const role = req.user.role;
  const age = role === "patient" ? calculateAge(date_of_birth) : null;
  if (age !== null && (age < 0 || age > 125)) {
    return res.status(400).json({ message: "Date of birth is outside the supported age range." });
  }

  const normalizedSpecialties = Array.isArray(req.body.specialties)
    ? [...new Set(req.body.specialties.map((value) => String(value).trim().toLowerCase()))]
    : [];
  if (role === "doctor") {
    if (!["general_practitioner", "specialist"].includes(req.body.doctor_type)) {
      return res.status(400).json({ message: "Choose a valid doctor type." });
    }
    if (
      normalizedSpecialties.length > 3 ||
      normalizedSpecialties.some((specialty) => !isValidSpecialty(specialty)) ||
      (req.body.doctor_type === "specialist" && normalizedSpecialties.length === 0) ||
      (req.body.doctor_type === "general_practitioner" && normalizedSpecialties.length > 0)
    ) {
      return res.status(400).json({
        message: "Specialists must select 1 to 3 valid specialties; general practitioners must not select specialties.",
      });
    }
  }

  const conditions = role === "patient" && Array.isArray(req.body.conditions)
    ? [...new Set(req.body.conditions.map((value) => String(value).trim()))]
    : [];
  if (
    role === "patient" &&
    (!["M", "F"].includes(req.body.sex) ||
      conditions.length === 0 ||
      conditions.some((condition) => !isKnownDisease(condition)))
  ) {
    return res.status(400).json({
      message: "Choose a valid sex and at least one recognized medical condition.",
    });
  }

  const connection = await db.getConnection();
  let transactionStarted = false;
  try {
    await connection.beginTransaction();
    transactionStarted = true;
    const first = firstname.toString().trim();
    const last = lastname.toString().trim();
    const name = `${first} ${last}`;

    await connection.execute(
      `UPDATE users
       SET name = ?, firstname = ?, lastname = ?, date_of_birth = ?,
           address = ?, phone = ?
       WHERE id = ?`,
      [name, first, last, date_of_birth, address.toString().trim(), phone.toString().trim(), req.user.id],
    );

    if (role === "doctor") {
      await connection.execute(
        `UPDATE users
         SET doctor_type = ?, specialty = ?, professional_info = ?
         WHERE id = ? AND role = 'doctor'`,
        [
          req.body.doctor_type,
          normalizedSpecialties[0] || null,
          req.body.professional_info?.toString().trim() || null,
          req.user.id,
        ],
      );
      await connection.execute("DELETE FROM doctor_specialties WHERE doctor_id = ?", [req.user.id]);
      for (const specialty of normalizedSpecialties) {
        const [result] = await connection.execute(
          `INSERT INTO doctor_specialties (doctor_id, specialty_id)
           SELECT ?, id FROM specialties WHERE slug = ?`,
          [req.user.id, specialty],
        );
        if (result.affectedRows === 0) {
          throw new Error(`Unknown specialty: ${specialty}`);
        }
      }
    } else if (role === "patient") {
      const [patientRows] = await connection.execute(
        "SELECT id FROM patients WHERE user_id = ? LIMIT 1 FOR UPDATE",
        [req.user.id],
      );
      if (patientRows.length === 0) {
        await connection.rollback();
        transactionStarted = false;
        return res.status(404).json({ message: "Patient profile not found." });
      }
      const patientId = patientRows[0].id;
      await connection.execute(
        `UPDATE patients
         SET firstname = ?, lastname = ?, address = ?, age = ?, date_of_birth = ?,
             sex = ?, disease = ?, phone = ?
         WHERE id = ?`,
        [
          first,
          last,
          address.toString().trim(),
          age,
          date_of_birth,
          req.body.sex,
          conditions[0],
          phone.toString().trim(),
          patientId,
        ],
      );
      await connection.execute("DELETE FROM patient_conditions WHERE patient_id = ?", [patientId]);
      for (const condition of conditions) {
        const [result] = await connection.execute(
          `INSERT INTO patient_conditions (patient_id, condition_id)
           SELECT ?, id FROM medical_conditions WHERE name = ?`,
          [patientId, condition],
        );
        if (result.affectedRows === 0) {
          throw new Error(`Unknown medical condition: ${condition}`);
        }
      }
    }

    await connection.commit();
    transactionStarted = false;
    return res.status(200).json({ message: "Profile updated." });
  } catch (err) {
    if (transactionStarted) await connection.rollback();
    console.error("Update profile error:", err);
    return res.status(500).json({ message: "Server error." });
  } finally {
    connection.release();
  }
};

const getDoctors = async (req, res) => {
  if (req.user.role !== "patient") {
    return res.status(403).json({ message: "Only patients can search for doctors." });
  }
  const search = String(req.query.search || "").trim();
  const specialty = String(req.query.specialty || "").trim().toLowerCase();
  const doctorType = String(req.query.doctor_type || req.query.doctorType || "").trim().toLowerCase();

  if (specialty && !isValidSpecialty(specialty)) {
    return res.status(400).json({ message: "Unknown specialty." });
  }
  if (doctorType && !["general_practitioner", "specialist"].includes(doctorType)) {
    return res.status(400).json({ message: "Doctor type must be general_practitioner or specialist." });
  }

  try {
    const params = [];
    let query = `
      SELECT u.id, u.name, u.doctor_type, u.professional_info,
             GROUP_CONCAT(DISTINCT s.slug ORDER BY s.slug SEPARATOR ',') AS specialties
      FROM users u
      LEFT JOIN doctor_specialties ds ON ds.doctor_id = u.id
      LEFT JOIN specialties s ON s.id = ds.specialty_id
      WHERE u.role = 'doctor'`;
    if (search) {
      query += " AND u.name LIKE ?";
      params.push(`%${search}%`);
    }
    if (doctorType) {
      query += " AND u.doctor_type = ?";
      params.push(doctorType);
    }
    if (specialty) {
      query += " AND EXISTS (SELECT 1 FROM doctor_specialties ds2 JOIN specialties s2 ON s2.id = ds2.specialty_id WHERE ds2.doctor_id = u.id AND s2.slug = ?)";
      params.push(specialty);
    }
    query += " GROUP BY u.id ORDER BY u.name LIMIT 100";

    const [rows] = await db.execute(query, params);
    return res.status(200).json({
      doctors: rows.map((row) => ({
        ...row,
        specialties: row.specialties ? row.specialties.split(",") : [],
      })),
    });
  } catch (err) {
    console.error("Get doctors error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

const getMedicalTaxonomy = async (_req, res) => {
  try {
    const [rows] = await db.execute(
      `SELECT c.name AS condition_name, s.slug AS specialty
       FROM medical_conditions c
       LEFT JOIN condition_specialties cs ON cs.condition_id = c.id
       LEFT JOIN specialties s ON s.id = cs.specialty_id
       ORDER BY c.name, s.slug`,
    );
    const conditions = new Map();
    for (const row of rows) {
      if (!conditions.has(row.condition_name)) conditions.set(row.condition_name, []);
      if (row.specialty) conditions.get(row.condition_name).push(row.specialty);
    }
    return res.status(200).json({
      specialties: getSpecialties(),
      conditions: [...conditions.entries()].map(([name, matches]) => ({
        name,
        specialties: matches,
      })),
    });
  } catch (err) {
    console.error("Get medical taxonomy error:", err);
    return res.status(500).json({ message: "Medical taxonomy is not available." });
  }
};

module.exports = { getMe, updateMe, getDoctors, getMedicalTaxonomy };
