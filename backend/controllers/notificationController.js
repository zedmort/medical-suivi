const db = require("../config/db");

const createDueAnalysisReminders = async (doctorId) => {
  const [dueRows] = await db.execute(
    `SELECT id, firstname, lastname, disease, next_analysis_date
     FROM patients
     WHERE doctor_id = ?
       AND next_analysis_date IS NOT NULL
       AND next_analysis_date <= CURDATE()
       AND (last_analysis_reminder_date IS NULL OR last_analysis_reminder_date < next_analysis_date)`,
    [doctorId]
  );

  for (const patient of dueRows) {
    const dueDate = patient.next_analysis_date
      ? new Date(patient.next_analysis_date).toISOString().slice(0, 10)
      : "date inconnue";

    await db.execute(
      `INSERT INTO notifications (user_id, title, body, type, ref_id)
       VALUES (?, ?, ?, ?, ?)`,
      [
        doctorId,
        "Rappel d'analyse",
        `Le patient ${patient.firstname} ${patient.lastname} est arrivé à la date prévue d'analyse (${dueDate}). Pensez à créer la demande d'analyse.`,
        "analysis_due",
        patient.id,
      ]
    );

    await db.execute(
      `UPDATE patients SET last_analysis_reminder_date = next_analysis_date WHERE id = ?`,
      [patient.id]
    );
  }
};

const notificationExists = async (userId, type, refId) => {
  if (!refId) return false;
  const [rows] = await db.execute(
    `SELECT id FROM notifications WHERE user_id = ? AND type = ? AND ref_id = ? LIMIT 1`,
    [userId, type, refId]
  );
  return rows.length > 0;
};

const resolvePatientRecordForUser = async (user) => {
  const [byUserId] = await db.execute(
    `SELECT id, firstname, lastname
     FROM patients
     WHERE user_id = ?
     ORDER BY created_at DESC
     LIMIT 1`,
    [user.id]
  );
  if (byUserId.length > 0) return byUserId[0];

  const [byName] = await db.execute(
    `SELECT id, firstname, lastname
     FROM patients
     WHERE LOWER(TRIM(CONCAT(firstname, ' ', lastname))) = LOWER(TRIM(?))
     ORDER BY created_at DESC
     LIMIT 1`,
    [user.name || ""]
  );
  return byName[0] || null;
};

const createPatientAutoNotifications = async (user) => {
  const patient = await resolvePatientRecordForUser(user);
  if (!patient) return;

  const [analyses] = await db.execute(
    `SELECT ar.id, ar.status, ar.created_at, ar2.id AS result_id
     FROM analysis_requests ar
     LEFT JOIN analysis_results ar2 ON ar2.request_id = ar.id
     WHERE ar.patient_id = ?
     ORDER BY ar.created_at DESC
     LIMIT 50`,
    [patient.id]
  );

  for (const analysis of analyses) {
    const analysisId = parseInt(analysis.id, 10);

    if (!(await notificationExists(user.id, "analysis", analysisId))) {
      await db.execute(
        `INSERT INTO notifications (user_id, title, body, type, ref_id)
         VALUES (?, ?, ?, ?, ?)`,
        [
          user.id,
          "New analysis request",
          "Your doctor created a new analysis request.",
          "analysis",
          analysisId,
        ]
      );
    }

    if (analysis.status === "completed" && analysis.result_id) {
      if (!(await notificationExists(user.id, "analysis_result", analysisId))) {
        await db.execute(
          `INSERT INTO notifications (user_id, title, body, type, ref_id)
           VALUES (?, ?, ?, ?, ?)`,
          [
            user.id,
            "Your analysis result is ready",
            "Your laboratory analysis result is now available.",
            "analysis_result",
            analysisId,
          ]
        );
      }
    }
  }

  const [prescriptions] = await db.execute(
    `SELECT id, status, created_at
     FROM prescriptions
     WHERE patient_id = ?
     ORDER BY created_at DESC
     LIMIT 50`,
    [patient.id]
  );

  for (const prescription of prescriptions) {
    const prescriptionId = parseInt(prescription.id, 10);

    if (!(await notificationExists(user.id, "prescription", prescriptionId))) {
      await db.execute(
        `INSERT INTO notifications (user_id, title, body, type, ref_id)
         VALUES (?, ?, ?, ?, ?)`,
        [
          user.id,
          "New prescription",
          "Your doctor sent a new prescription to pharmacy.",
          "prescription",
          prescriptionId,
        ]
      );
    }

    if (prescription.status === "dispensed") {
      if (!(await notificationExists(user.id, "dispensed", prescriptionId))) {
        await db.execute(
          `INSERT INTO notifications (user_id, title, body, type, ref_id)
           VALUES (?, ?, ?, ?, ?)`,
          [
            user.id,
            "Your medication is ready",
            "Your pharmacy has marked your medication as ready.",
            "dispensed",
            prescriptionId,
          ]
        );
      }
    }
  }
};

// Internal helper — called by other controllers
const createNotification = async (userId, title, body, type = "info", refId = null) => {
  try {
    await db.execute(
      `INSERT INTO notifications (user_id, title, body, type, ref_id) VALUES (?, ?, ?, ?, ?)`,
      [userId, title, body, type, refId]
    );
  } catch (err) {
    console.error("Create notification error:", err);
  }
};

// GET /api/notifications
const getNotifications = async (req, res) => {
  try {
    if (req.user.role === "doctor") {
      await createDueAnalysisReminders(req.user.id);
    }

    if (req.user.role === "patient") {
      await createPatientAutoNotifications(req.user);
    }

    const [rows] = await db.execute(
      `SELECT * FROM notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT 50`,
      [req.user.id]
    );
    const unread = rows.filter(n => !n.is_read).length;
    return res.status(200).json({ notifications: rows, unread });
  } catch (err) {
    console.error("Get notifications error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

// PATCH /api/notifications/:id/read
const markRead = async (req, res) => {
  try {
    await db.execute(
      `UPDATE notifications SET is_read = 1 WHERE id = ? AND user_id = ?`,
      [req.params.id, req.user.id]
    );
    return res.status(200).json({ message: "Marked as read." });
  } catch (err) {
    console.error("Mark read error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

// PATCH /api/notifications/read-all
const markAllRead = async (req, res) => {
  try {
    await db.execute(
      `UPDATE notifications SET is_read = 1 WHERE user_id = ?`,
      [req.user.id]
    );
    return res.status(200).json({ message: "All marked as read." });
  } catch (err) {
    console.error("Mark all read error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

module.exports = { createNotification, getNotifications, markRead, markAllRead };
