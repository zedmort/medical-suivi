const db = require("../config/db");
const upload = require("../config/multer");
const { createNotification } = require("./notificationController");

const findPatientUserId = async (patientId) => {
  const [rows] = await db.execute(
    `SELECT p.user_id AS id, CONCAT(p.firstname, ' ', p.lastname) AS full_name
     FROM patients p
     WHERE p.id = ?
     LIMIT 1`,
    [patientId]
  );

  if (!rows[0]) return null;
  if (rows[0].id) return rows[0].id;

  const [legacy] = await db.execute(
    `SELECT id FROM users WHERE role = 'patient' AND LOWER(TRIM(name)) = LOWER(TRIM(?)) LIMIT 1`,
    [rows[0].full_name]
  );
  return legacy[0]?.id || null;
};

// GET /api/prescriptions
const getPrescriptions = async (req, res) => {
  const { role, id } = req.user;

  try {
    let rows;

    if (role === "pharmacy") {
      [rows] = await db.execute(
        `SELECT pr.*, p.firstname, p.lastname, p.address, p.phone, p.disease,
                u.name AS doctor_name
         FROM prescriptions pr
         JOIN patients p ON p.id = pr.patient_id
         JOIN users u ON u.id = pr.doctor_id
         WHERE pr.pharmacy_id = ? ORDER BY pr.created_at DESC`,
        [id]
      );
    } else if (role === "doctor") {
      [rows] = await db.execute(
        `SELECT pr.*, p.firstname, p.lastname, p.address, p.phone, p.disease,
                u.name AS pharmacy_name
         FROM prescriptions pr
         JOIN patients p ON p.id = pr.patient_id
         JOIN users u ON u.id = pr.pharmacy_id
         WHERE pr.doctor_id = ? ORDER BY pr.created_at DESC`,
        [id]
      );
    } else if (role === "patient") {
      const [patientRows] = await db.execute(
        `SELECT id FROM patients
         WHERE user_id = ?
         LIMIT 1`,
        [id]
      );

      let patientId = patientRows[0]?.id;

      if (!patientId) {
        const [legacyRows] = await db.execute(
          `SELECT id FROM patients
           WHERE LOWER(TRIM(CONCAT(firstname, ' ', lastname))) = LOWER(TRIM(?))
           ORDER BY created_at DESC
           LIMIT 1`,
          [req.user.name || ""]
        );
        patientId = legacyRows[0]?.id;
      }

      if (!patientId) {
        return res.status(200).json({ prescriptions: [] });
      }

      [rows] = await db.execute(
        `SELECT pr.*, u.name AS pharmacy_name
         FROM prescriptions pr
         JOIN users u ON u.id = pr.pharmacy_id
         WHERE pr.patient_id = ?
         ORDER BY pr.created_at DESC`,
        [patientId]
      );
    } else {
      return res.status(403).json({ message: "Access denied." });
    }

    return res.status(200).json({ prescriptions: rows });
  } catch (err) {
    console.error("Get prescriptions error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

// POST /api/prescriptions/create  (doctor only)
const createPrescription = async (req, res) => {
  if (req.user.role !== "doctor") {
    return res.status(403).json({ message: "Only doctors can create prescriptions." });
  }

  const { patient_id, pharmacy_id, notes } = req.body;

  if (!patient_id || !pharmacy_id) {
    return res.status(400).json({ message: "patient_id and pharmacy_id are required." });
  }

  const file_url = req.file ? upload.getFileUrl(req.file) : null;

  try {
    // Verify patient belongs to this doctor
    const [pt] = await db.execute(
      `SELECT id, firstname, lastname, address, phone, disease FROM patients WHERE id = ? AND doctor_id = ?`,
      [patient_id, req.user.id]
    );
    if (pt.length === 0) return res.status(404).json({ message: "Patient not found." });
    const patient = pt[0];

    const [result] = await db.execute(
      `INSERT INTO prescriptions (doctor_id, patient_id, pharmacy_id, notes, file_url, status) VALUES (?, ?, ?, ?, ?, 'pending')`,
      [req.user.id, patient_id, pharmacy_id, notes || null, file_url]
    );

    // Notify pharmacy
    await createNotification(
      pharmacy_id,
      "Nouvelle ordonnance",
      `Patient: ${patient.firstname} ${patient.lastname}\nAdresse: ${patient.address}\nTél: ${patient.phone || 'N/A'}\nMaladie: ${patient.disease}\nNotes: ${notes || 'Aucune'}`,
      "prescription",
      result.insertId
    );

    const patientUserId = await findPatientUserId(patient_id);
    if (patientUserId) {
      await createNotification(
        patientUserId,
        "New prescription",
        "Your doctor sent a new prescription to pharmacy.",
        "prescription",
        result.insertId
      );
    }

    return res.status(201).json({ message: "Prescription created.", prescriptionId: result.insertId, file_url });
  } catch (err) {
    console.error("Create prescription error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

// PATCH /api/prescriptions/:id/status  (pharmacy only)
const updateStatus = async (req, res) => {
  if (req.user.role !== "pharmacy") {
    return res.status(403).json({ message: "Only pharmacy staff can update prescription status." });
  }
  const { id } = req.params;
  const { status } = req.body;
  const validStatuses = ["pending", "dispensed"];
  if (!validStatuses.includes(status)) {
    return res.status(400).json({ message: "Status must be pending or dispensed." });
  }
  try {
    // Get prescription + patient info to notify doctor
    const [rows] = await db.execute(
      `SELECT pr.doctor_id, pr.patient_id, p.firstname, p.lastname
       FROM prescriptions pr
       JOIN patients p ON p.id = pr.patient_id
       WHERE pr.id = ? AND pr.pharmacy_id = ?`,
      [id, req.user.id]
    );
    if (rows.length === 0) return res.status(404).json({ message: "Prescription not found." });

    await db.execute(
      `UPDATE prescriptions SET status = ? WHERE id = ? AND pharmacy_id = ?`,
      [status, id, req.user.id]
    );

    if (status === "dispensed") {
      await createNotification(
        rows[0].doctor_id,
        "Médicaments livrés",
        `L'ordonnance pour ${rows[0].firstname} ${rows[0].lastname} a été livrée par la pharmacie.`,
        "dispensed",
        parseInt(id)
      );

      const patientUserId = await findPatientUserId(rows[0].patient_id);
      if (patientUserId) {
        await createNotification(
          patientUserId,
          "Your medication is ready",
          "Your pharmacy has marked your medication as ready.",
          "dispensed",
          parseInt(id)
        );
      }
    }

    return res.status(200).json({ message: "Status updated." });
  } catch (err) {
    console.error("Update prescription status error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

module.exports = { getPrescriptions, createPrescription, updateStatus };
