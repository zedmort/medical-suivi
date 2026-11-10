const db = require("../config/db");
const { isDiseaseAllowedForSpecialty, getDiseasesForSpecialty } =
  require("../config/medicalTaxonomy");
const { createNotification } = require("./notificationController");
const { findPatientForUser } = require("../utils/patientIdentity");

const findPatientForLoggedUser = async (user) => {
  const identity = await findPatientForUser(user);
  if (!identity) return null;
  const [rows] = await db.execute(
    "SELECT * FROM patients WHERE id = ? LIMIT 1",
    [identity.id],
  );
  return rows[0] || null;
};

const getDoctorSpecialties = async (doctorId) => {
  const [rows] = await db.execute(
    `SELECT s.slug
     FROM doctor_specialties ds
     JOIN specialties s ON s.id = ds.specialty_id
     WHERE ds.doctor_id = ?
     UNION
     SELECT specialty AS slug FROM users
     WHERE id = ? AND role = 'doctor' AND specialty IS NOT NULL AND specialty <> ''`,
    [doctorId, doctorId],
  );
  return rows.map((row) => row.slug);
};

// GET /api/patients/available — doctor lists unassigned existing patient accounts matching specialty
const getAvailablePatients = async (req, res) => {
  if (req.user.role !== "doctor") {
    return res.status(403).json({ message: "Access denied." });
  }

  try {
    const [doctor] = await db.execute(
      "SELECT doctor_type FROM users WHERE id = ? AND role = 'doctor'",
      [req.user.id],
    );
    if (!doctor[0]) return res.status(404).json({ message: "Doctor not found." });

    let rows;
    if (doctor[0].doctor_type === "general_practitioner") {
      [rows] = await db.execute(
        `SELECT p.id, p.user_id, p.firstname, p.lastname, p.address, p.age,
                p.sex, p.disease, p.phone, p.created_at, u.email
         FROM patients p
         LEFT JOIN users u ON u.id = p.user_id
         WHERE p.doctor_id IS NULL AND p.user_id IS NOT NULL
         ORDER BY p.lastname ASC, p.firstname ASC`,
      );
    } else {
      [rows] = await db.execute(
        `SELECT DISTINCT p.id, p.user_id, p.firstname, p.lastname, p.address,
                p.age, p.sex, p.disease, p.phone, p.created_at, u.email
         FROM patients p
         JOIN patient_conditions pc ON pc.patient_id = p.id
         JOIN condition_specialties cs ON cs.condition_id = pc.condition_id
         JOIN doctor_specialties ds ON ds.specialty_id = cs.specialty_id
         LEFT JOIN users u ON u.id = p.user_id
         WHERE p.doctor_id IS NULL AND p.user_id IS NOT NULL AND ds.doctor_id = ?
         ORDER BY p.lastname ASC, p.firstname ASC`,
        [req.user.id],
      );
    }

    return res.status(200).json({ patients: rows });
  } catch (err) {
    console.error("Get available patients error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

const getDoctorRecommendations = async (req, res) => {
  if (req.user.role !== "patient") {
    return res.status(403).json({ message: "Only patients can request doctor recommendations." });
  }
  try {
    const [patients] = await db.execute(
      "SELECT id FROM patients WHERE user_id = ? LIMIT 1",
      [req.user.id],
    );
    if (patients.length === 0) {
      return res.status(404).json({ message: "Patient profile not found." });
    }

    const [matches] = await db.execute(
      `SELECT u.id, u.name, u.doctor_type, u.professional_info,
              GROUP_CONCAT(DISTINCT s.slug ORDER BY s.slug SEPARATOR ',') AS specialties
       FROM patient_conditions pc
       JOIN condition_specialties cs ON cs.condition_id = pc.condition_id
       JOIN doctor_specialties ds ON ds.specialty_id = cs.specialty_id
       JOIN users u ON u.id = ds.doctor_id AND u.role = 'doctor'
       JOIN specialties s ON s.id = ds.specialty_id
       WHERE pc.patient_id = ?
       GROUP BY u.id
       ORDER BY u.name
       LIMIT 100`,
      [patients[0].id],
    );

    let doctors = matches.map((doctor) => ({
      ...doctor,
      specialties: doctor.specialties ? doctor.specialties.split(",") : [],
      recommendation: "condition_match",
    }));
    if (doctors.length === 0) {
      const [generalPractitioners] = await db.execute(
        `SELECT id, name, doctor_type, professional_info, NULL AS specialties
         FROM users
         WHERE role = 'doctor' AND doctor_type = 'general_practitioner'
         ORDER BY name
         LIMIT 100`,
      );
      doctors = generalPractitioners.map((doctor) => ({
        ...doctor,
        specialties: [],
        recommendation: "general_practitioner",
      }));
    }
    return res.status(200).json({
      doctors,
      hasConditionMatch: matches.length > 0,
    });
  } catch (err) {
    console.error("Get doctor recommendations error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

const assignTreatingDoctor = async (req, res) => {
  if (req.user.role !== "patient") {
    return res.status(403).json({ message: "Only patients can choose their treating doctor." });
  }
  const doctorId = Number.parseInt(req.body.doctor_id, 10);
  if (!Number.isInteger(doctorId) || doctorId <= 0) {
    return res.status(400).json({ message: "A valid doctor_id is required." });
  }

  const connection = await db.getConnection();
  let transactionStarted = false;
  try {
    await connection.beginTransaction();
    transactionStarted = true;
    const [patientRows] = await connection.execute(
      "SELECT id, doctor_id FROM patients WHERE user_id = ? LIMIT 1 FOR UPDATE",
      [req.user.id],
    );
    if (patientRows.length === 0) {
      await connection.rollback();
      transactionStarted = false;
      return res.status(404).json({ message: "Patient profile not found." });
    }
    const [doctors] = await connection.execute(
      "SELECT id, name FROM users WHERE id = ? AND role = 'doctor' LIMIT 1",
      [doctorId],
    );
    if (doctors.length === 0) {
      await connection.rollback();
      transactionStarted = false;
      return res.status(404).json({ message: "Doctor not found." });
    }

    const patientId = patientRows[0].id;
    await connection.execute(
      "UPDATE patients SET doctor_id = ? WHERE id = ?",
      [doctorId, patientId],
    );
    await connection.commit();
    transactionStarted = false;

    await createNotification(
      doctorId,
      "New patient selected you",
      "A patient selected you as their treating doctor.",
      "patient_assignment",
      patientId,
    );
    return res.status(200).json({
      message: "Treating doctor updated.",
      doctor: { id: doctorId, name: doctors[0].name },
    });
  } catch (err) {
    if (transactionStarted) await connection.rollback();
    console.error("Assign treating doctor error:", err);
    return res.status(500).json({ message: "Server error." });
  } finally {
    connection.release();
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
    const [doctorRows] = await db.execute(
      "SELECT doctor_type FROM users WHERE id = ? AND role = 'doctor'",
      [req.user.id],
    );
    if (!doctorRows[0]) return res.status(404).json({ message: "Doctor not found." });

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

    if (doctorRows[0].doctor_type !== "general_practitioner") {
      const [matches] = await db.execute(
        `SELECT 1
         FROM patient_conditions pc
         JOIN condition_specialties cs ON cs.condition_id = pc.condition_id
         JOIN doctor_specialties ds ON ds.specialty_id = cs.specialty_id
         WHERE pc.patient_id = ? AND ds.doctor_id = ?
         LIMIT 1`,
        [patientId, req.user.id],
      );
      if (matches.length === 0) {
        return res.status(400).json({
          message: "The patient's recorded conditions do not match your specialties.",
        });
      }
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
    const [doctorRows] = await db.execute(
      "SELECT doctor_type FROM users WHERE id = ? AND role = 'doctor'",
      [req.user.id],
    );
    if (!doctorRows[0]) return res.status(404).json({ message: "Doctor not found." });

    const doctorSpecialties = await getDoctorSpecialties(req.user.id);
    if (
      doctorRows[0].doctor_type !== "general_practitioner" &&
      !doctorSpecialties.some((specialty) =>
        isDiseaseAllowedForSpecialty(specialty, disease))
    ) {
      return res.status(400).json({
        message: "The patient's recorded condition does not match your specialties.",
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
        message: "Patient profile is not linked to this account.",
      });
    }
    const [conditionRows] = await db.execute(
      `SELECT c.name
       FROM patient_conditions pc
       JOIN medical_conditions c ON c.id = pc.condition_id
       WHERE pc.patient_id = ?
       ORDER BY c.name`,
      [patient.id],
    );
    let treatingDoctor = null;
    if (patient.doctor_id) {
      const [doctorRows] = await db.execute(
        "SELECT id, name FROM users WHERE id = ? AND role = 'doctor'",
        [patient.doctor_id],
      );
      treatingDoctor = doctorRows[0] || null;
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
        conditions: conditionRows.map((row) => row.name),
        doctor: treatingDoctor,
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

module.exports = {
  createPatient,
  getPatients,
  getAvailablePatients,
  getPatient,
  updatePatient,
  getMyOverview,
  getDoctorRecommendations,
  assignTreatingDoctor,
};
