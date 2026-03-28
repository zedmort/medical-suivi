const db = require("../config/db");
const {
  isDiseaseAllowedForSpecialty,
  getDiseasesForSpecialty,
} = require("../config/medicalTaxonomy");

const findPatientForLoggedUser = async (user) => {
  const [byUserId] = await db.execute(
    `SELECT p.* FROM patients p WHERE p.user_id = ? LIMIT 1`,
    [user.id]
  );
  if (byUserId.length > 0) {
    return byUserId[0];
  }

  const [rows] = await db.execute(
    `SELECT p.*
     FROM patients p
     WHERE LOWER(TRIM(CONCAT(p.firstname, ' ', p.lastname))) = LOWER(TRIM(?))
     ORDER BY p.created_at DESC
     LIMIT 1`,
    [user.name || ""]
  );

  return rows[0] || null;
};

const getDoctorSpecialty = async (doctorId) => {
  const [rows] = await db.execute(
    `SELECT specialty FROM users WHERE id = ? AND role = 'doctor' LIMIT 1`,
    [doctorId]
  );
  return rows[0]?.specialty || null;
};

// GET /api/patients/available — doctor lists unassigned existing patient accounts matching specialty
const getAvailablePatients = async (req, res) => {
  if (req.user.role !== "doctor") {
    return res.status(403).json({ message: "Access denied." });
  }

  try {
    const doctorSpecialty = await getDoctorSpecialty(req.user.id);
    if (!doctorSpecialty) {
      return res.status(400).json({ message: "Doctor specialty is required before adding patients." });
    }

    const allowedDiseases = getDiseasesForSpecialty(doctorSpecialty);
    if (allowedDiseases.length === 0) {
      return res.status(200).json({ patients: [] });
    }

    const placeholders = allowedDiseases.map(() => "?").join(", ");
    const [rows] = await db.execute(
      `SELECT p.id, p.user_id, p.firstname, p.lastname, p.address, p.age, p.sex, p.disease, p.phone, p.created_at,
              u.email
       FROM patients p
       LEFT JOIN users u ON u.id = p.user_id
       WHERE p.doctor_id IS NULL
         AND p.user_id IS NOT NULL
         AND p.disease IN (${placeholders})
       ORDER BY p.lastname ASC, p.firstname ASC`,
      allowedDiseases
    );

    return res.status(200).json({ patients: rows });
  } catch (err) {
    console.error("Get available patients error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

// POST /api/patients  — doctor links an existing patient account
const createPatient = async (req, res) => {
  if (req.user.role !== "doctor") {
    return res.status(403).json({ message: "Only doctors can create patients." });
  }

  const patientId = parseInt(req.body.patient_id, 10);
  if (Number.isNaN(patientId) || patientId <= 0) {
    return res.status(400).json({ message: "patient_id is required." });
  }

  try {
    const doctorSpecialty = await getDoctorSpecialty(req.user.id);
    if (!doctorSpecialty) {
      return res.status(400).json({ message: "Doctor specialty is required before adding patients." });
    }

    const [rows] = await db.execute(
      `SELECT id, doctor_id, user_id, disease
       FROM patients
       WHERE id = ?
       LIMIT 1`,
      [patientId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ message: "Patient not found." });
    }

    const patient = rows[0];
    if (!patient.user_id) {
      return res.status(400).json({ message: "Only patient accounts created by registration can be linked." });
    }

    if (patient.doctor_id && Number(patient.doctor_id) !== Number(req.user.id)) {
      return res.status(409).json({ message: "Patient is already assigned to another doctor." });
    }

    if (!isDiseaseAllowedForSpecialty(doctorSpecialty, patient.disease)) {
      const allowed = getDiseasesForSpecialty(doctorSpecialty);
      return res.status(400).json({
        message: `Disease is not allowed for your specialty (${doctorSpecialty}). Allowed diseases: ${allowed.join(", ")}.`,
      });
    }

    const [result] = await db.execute(
      `UPDATE patients
       SET doctor_id = ?
       WHERE id = ? AND (doctor_id IS NULL OR doctor_id = ?)`,
      [req.user.id, patientId, req.user.id]
    );

    if (result.affectedRows === 0) {
      return res.status(409).json({ message: "Patient is already assigned to another doctor." });
    }

    return res.status(201).json({
      message: "Patient linked.",
      patientId,
    });
  } catch (err) {
    console.error("Create patient error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

// GET /api/patients  — doctor lists their patients
const getPatients = async (req, res) => {
  if (req.user.role !== "doctor") {
    return res.status(403).json({ message: "Access denied." });
  }

  try {
    const [rows] = await db.execute(
      `SELECT * FROM patients WHERE doctor_id = ? ORDER BY lastname ASC`,
      [req.user.id]
    );
    return res.status(200).json({ patients: rows });
  } catch (err) {
    console.error("Get patients error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

// GET /api/patients/:id
const getPatient = async (req, res) => {
  if (req.user.role !== "doctor") {
    return res.status(403).json({ message: "Access denied." });
  }

  try {
    const [rows] = await db.execute(
      `SELECT * FROM patients WHERE id = ? AND doctor_id = ?`,
      [req.params.id, req.user.id]
    );
    if (rows.length === 0) return res.status(404).json({ message: "Patient not found." });
    return res.status(200).json({ patient: rows[0] });
  } catch (err) {
    console.error("Get patient error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

// PUT /api/patients/:id — doctor updates patient
const updatePatient = async (req, res) => {
  if (req.user.role !== "doctor") {
    return res.status(403).json({ message: "Access denied." });
  }

  const { firstname, lastname, address, age, sex, disease, phone, next_analysis_date } = req.body;

  try {
    const doctorSpecialty = await getDoctorSpecialty(req.user.id);
    if (!doctorSpecialty) {
      return res.status(400).json({ message: "Doctor specialty is required before updating patients." });
    }

    if (!isDiseaseAllowedForSpecialty(doctorSpecialty, disease)) {
      const allowed = getDiseasesForSpecialty(doctorSpecialty);
      return res.status(400).json({
        message: `Disease is not allowed for your specialty (${doctorSpecialty}). Allowed diseases: ${allowed.join(", ")}.`,
      });
    }

    const [result] = await db.execute(
      `UPDATE patients SET firstname=?, lastname=?, address=?, age=?, sex=?, disease=?, phone=?, next_analysis_date=?
       WHERE id=? AND doctor_id=?`,
      [
        firstname,
        lastname,
        address,
        parseInt(age),
        sex,
        disease,
        phone || null,
        next_analysis_date || null,
        req.params.id,
        req.user.id,
      ]
    );
    if (result.affectedRows === 0) return res.status(404).json({ message: "Patient not found." });
    return res.status(200).json({ message: "Patient updated." });
  } catch (err) {
    console.error("Update patient error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

// GET /api/patients/me/overview — patient-only dashboard summary
const getMyOverview = async (req, res) => {
  if (req.user.role !== "patient") {
    return res.status(403).json({ message: "Access denied." });
  }

  try {
    const patient = await findPatientForLoggedUser(req.user);
    if (!patient) {
      return res.status(404).json({
        message:
          "Patient profile not linked yet. Ask your doctor to use your exact full name in the patient record.",
      });
    }

    const [analyses] = await db.execute(
      `SELECT ar.id, ar.status, ar.created_at, ar.notes, ar2.file_url AS result_url, ar2.created_at AS result_uploaded_at
       FROM analysis_requests ar
       LEFT JOIN analysis_results ar2 ON ar2.request_id = ar.id
       WHERE ar.patient_id = ?
       ORDER BY ar.created_at DESC`,
      [patient.id]
    );

    const [prescriptions] = await db.execute(
      `SELECT id, status, created_at, notes, file_url
       FROM prescriptions
       WHERE patient_id = ?
       ORDER BY created_at DESC`,
      [patient.id]
    );

    const analysisPending = analyses.filter((a) => a.status === "pending").length;
    const analysisCompleted = analyses.filter((a) => a.status === "completed").length;
    const medsPending = prescriptions.filter((p) => p.status === "pending").length;
    const medsReady = prescriptions.filter((p) => p.status === "dispensed").length;

    let progression = {
      level: "monitoring",
      label: "Under monitoring",
      message: "Continue following your doctor's care plan.",
    };

    if (analysisPending > 0 || medsPending > 0) {
      progression = {
        level: "attention",
        label: "Needs attention",
        message: "Some analyses or medications are still pending.",
      };
    } else if (analysisCompleted > 0 || medsReady > 0) {
      progression = {
        level: "good",
        label: "Doing good",
        message: "Latest required items are completed or ready.",
      };
    }

    const timeline = [
      ...analyses.map((a) => ({
        type: "analysis",
        title: a.status === "completed" ? "Analysis completed" : "Analysis requested",
        subtitle: a.status === "completed" ? "Result available" : "Waiting for laboratory result",
        date: a.result_uploaded_at || a.created_at,
      })),
      ...prescriptions.map((p) => ({
        type: "medication",
        title: p.status === "dispensed" ? "Medication ready" : "Medication pending",
        subtitle: p.status === "dispensed" ? "Pharmacy has marked it ready" : "Pharmacy is preparing your medication",
        date: p.created_at,
      })),
    ]
      .sort((a, b) => new Date(b.date) - new Date(a.date))
      .slice(0, 20);

    return res.status(200).json({
      patient: {
        id: patient.id,
        firstname: patient.firstname,
        lastname: patient.lastname,
        disease: patient.disease,
        next_analysis_date: patient.next_analysis_date,
      },
      stats: {
        analysis_pending: analysisPending,
        analysis_completed: analysisCompleted,
        meds_pending: medsPending,
        meds_ready: medsReady,
      },
      progression,
      timeline,
    });
  } catch (err) {
    console.error("Get patient overview error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

module.exports = { createPatient, getPatients, getAvailablePatients, getPatient, updatePatient, getMyOverview };
