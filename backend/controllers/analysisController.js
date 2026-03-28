const db = require("../config/db");
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

// POST /api/analysis/create  (doctor only)
const createRequest = async (req, res) => {
  if (req.user.role !== "doctor") {
    return res.status(403).json({ message: "Only doctors can create analysis requests." });
  }

  const { patient_id, labo_id, notes } = req.body;

  if (!patient_id || !labo_id) {
    return res.status(400).json({ message: "patient_id and labo_id are required." });
  }

  try {
    const [pt] = await db.execute(
      `SELECT id, firstname, lastname, address, disease FROM patients WHERE id = ? AND doctor_id = ?`,
      [patient_id, req.user.id]
    );
    if (pt.length === 0) return res.status(404).json({ message: "Patient not found." });
    const patient = pt[0];

    const file_url = req.file ? `/uploads/${req.file.filename}` : null;

    const [result] = await db.execute(
      `INSERT INTO analysis_requests (doctor_id, patient_id, labo_id, notes, file_url, status) VALUES (?, ?, ?, ?, ?, 'pending')`,
      [req.user.id, patient_id, labo_id, notes || null, file_url]
    );

    await createNotification(
      labo_id,
      "Nouvelle demande d'analyse",
      `Patient: ${patient.firstname} ${patient.lastname} — ${patient.disease}\nAdresse: ${patient.address}\nNotes: ${notes || 'Aucune'}${file_url ? '\nFichier joint: Oui' : ''}`,
      "analysis",
      result.insertId
    );

    const patientUserId = await findPatientUserId(patient_id);
    if (patientUserId) {
      await createNotification(
        patientUserId,
        "New analysis request",
        "Your doctor created a new analysis request.",
        "analysis",
        result.insertId
      );
    }

    return res.status(201).json({ message: "Analysis request created.", requestId: result.insertId });
  } catch (err) {
    console.error("Create analysis request error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

// GET /api/analysis/patient/:patientId  (doctor only)
const getPatientAnalysis = async (req, res) => {
  if (req.user.role !== "doctor") return res.status(403).json({ message: "Access denied." });
  try {
    const [rows] = await db.execute(
      `SELECT ar.*, ar2.file_url AS result_url, ar2.created_at AS result_uploaded_at
       FROM analysis_requests ar
       LEFT JOIN analysis_results ar2 ON ar2.request_id = ar.id
       WHERE ar.patient_id = ? AND ar.doctor_id = ?
       ORDER BY ar.created_at DESC`,
      [req.params.patientId, req.user.id]
    );
    return res.status(200).json({ analyses: rows });
  } catch (err) {
    console.error("Get patient analysis error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

// POST /api/analysis/upload-result  (labo only)
const uploadResult = async (req, res) => {
  if (req.user.role !== "labo") {
    return res.status(403).json({ message: "Only laboratory staff can upload results." });
  }

  const { request_id } = req.body;
  if (!request_id || !req.file) {
    return res.status(400).json({ message: "request_id and file are required." });
  }

  try {
    const [rows] = await db.execute(
      `SELECT ar.id, ar.doctor_id, p.firstname, p.lastname
       FROM analysis_requests ar
       JOIN patients p ON p.id = ar.patient_id
       WHERE ar.id = ? AND ar.labo_id = ?`,
      [request_id, req.user.id]
    );
    if (rows.length === 0) return res.status(404).json({ message: "Request not found or not assigned to you." });

    const row = rows[0];
    const file_url = `/uploads/${req.file.filename}`;

    await db.execute(`INSERT INTO analysis_results (request_id, file_url) VALUES (?, ?)`, [request_id, file_url]);
    await db.execute(`UPDATE analysis_requests SET status = 'completed' WHERE id = ?`, [request_id]);

    await createNotification(
      row.doctor_id,
      "Résultat d'analyse disponible",
      `Les résultats d'analyse pour ${row.firstname} ${row.lastname} sont prêts.`,
      "analysis_result",
      parseInt(request_id)
    );

    const [patientRow] = await db.execute(
      `SELECT patient_id FROM analysis_requests WHERE id = ? LIMIT 1`,
      [request_id]
    );
    const patientId = patientRow[0]?.patient_id;
    if (patientId) {
      const patientUserId = await findPatientUserId(patientId);
      if (patientUserId) {
        await createNotification(
          patientUserId,
          "Your analysis result is ready",
          "Your laboratory analysis result is now available.",
          "analysis_result",
          parseInt(request_id)
        );
      }
    }

    return res.status(201).json({ message: "Result uploaded.", file_url });
  } catch (err) {
    console.error("Upload result error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

// GET /api/analysis/my-requests
const getMyRequests = async (req, res) => {
  const { role, id } = req.user;
  try {
    let rows;
    if (role === "doctor") {
      [rows] = await db.execute(
        `SELECT ar.*, ar2.file_url AS result_url, ar2.created_at AS result_uploaded_at,
                p.firstname, p.lastname, p.address, p.age, p.sex, p.disease, p.phone,
                u.name AS labo_name
         FROM analysis_requests ar
         JOIN patients p ON p.id = ar.patient_id
         JOIN users u ON u.id = ar.labo_id
         LEFT JOIN analysis_results ar2 ON ar2.request_id = ar.id
         WHERE ar.doctor_id = ? ORDER BY ar.created_at DESC`,
        [id]
      );
    } else if (role === "labo") {
      [rows] = await db.execute(
        `SELECT ar.*, ar2.file_url AS result_url, ar2.created_at AS result_uploaded_at,
                p.firstname, p.lastname, p.address, p.age, p.sex, p.disease, p.phone,
                u.name AS doctor_name
         FROM analysis_requests ar
         JOIN patients p ON p.id = ar.patient_id
         JOIN users u ON u.id = ar.doctor_id
         LEFT JOIN analysis_results ar2 ON ar2.request_id = ar.id
         WHERE ar.labo_id = ? ORDER BY ar.created_at DESC`,
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
        return res.status(200).json({ requests: [] });
      }

      [rows] = await db.execute(
        `SELECT ar.*, ar2.file_url AS result_url, ar2.created_at AS result_uploaded_at,
                u.name AS labo_name
         FROM analysis_requests ar
         JOIN users u ON u.id = ar.labo_id
         LEFT JOIN analysis_results ar2 ON ar2.request_id = ar.id
         WHERE ar.patient_id = ?
         ORDER BY ar.created_at DESC`,
        [patientId]
      );
    } else {
      return res.status(403).json({ message: "Access denied." });
    }
    return res.status(200).json({ requests: rows });
  } catch (err) {
    console.error("Get my requests error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

module.exports = { createRequest, getPatientAnalysis, uploadResult, getMyRequests };
