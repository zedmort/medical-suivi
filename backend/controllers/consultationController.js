const crypto = require("crypto");
const db = require("../config/db");
const { createNotification } = require("./notificationController");

const DEMO_SUCCESS_CARD = "4111111111111111";
const DEMO_DECLINED_CARD = "4000000000000002";

const luhnValid = (digits) => {
  let sum = 0;
  let doubleDigit = false;
  for (let index = digits.length - 1; index >= 0; index--) {
    let digit = Number(digits[index]);
    if (doubleDigit) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }
    sum += digit;
    doubleDigit = !doubleDigit;
  }
  return sum % 10 === 0;
};

const validExpiry = (value) => {
  if (typeof value !== "string" || !/^\d{2}\/\d{2}$/.test(value)) {
    return false;
  }
  const [month, shortYear] = value.split("/").map(Number);
  if (month < 1 || month > 12) return false;
  const expiry = new Date(2000 + shortYear, month, 0, 23, 59, 59, 999);
  return expiry >= new Date();
};

const validDemoCard = (cardNumber) => {
  const digits = String(cardNumber || "").replace(/\s/g, "");
  return (
    /^\d{16}$/.test(digits) &&
    luhnValid(digits) &&
    [DEMO_SUCCESS_CARD, DEMO_DECLINED_CARD].includes(digits)
  );
};

const getPrice = async (req, res) => {
  if (req.user.role !== "patient") {
    return res.status(403).json({ message: "Only patients can request a consultation price." });
  }
  try {
    const [rows] = await db.execute(
      `SELECT setting_value
       FROM system_settings
       WHERE setting_key = 'symptom_consultation_amount_dzd'
       LIMIT 1`,
    );
    return res.status(200).json({
      amountDzd: rows.length ? Number(rows[0].setting_value) : null,
      currency: "DZD",
      simulated: true,
    });
  } catch (err) {
    console.error("Get consultation price error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

const createPaidConsultation = async (req, res) => {
  if (req.user.role !== "patient") {
    return res.status(403).json({ message: "Only patients can request symptom consultations." });
  }
  const symptoms = req.body.symptoms?.toString().trim() ?? "";
  const notes = req.body.notes?.toString().trim() ?? "";
  const doctorId = req.body.doctor_id ? Number.parseInt(req.body.doctor_id, 10) : null;
  const idempotencyKey = req.body.idempotency_key?.toString() ?? "";
  const cardholder = req.body.cardholder?.toString().trim() ?? "";
  const cardDigits = req.body.card_number?.toString().replace(/\s/g, "") ?? "";

  if (symptoms.length < 10 || symptoms.length > 5000) {
    return res.status(400).json({ message: "Describe your symptoms in 10 to 5000 characters." });
  }
  if (notes.length > 2000) {
    return res.status(400).json({ message: "Additional information is too long." });
  }
  if (
    !/^[A-Za-z0-9_-]{16,64}$/.test(idempotencyKey) ||
    (doctorId !== null && (!Number.isInteger(doctorId) || doctorId <= 0))
  ) {
    return res.status(400).json({ message: "Payment request is invalid." });
  }
  if (
    cardholder.length < 2 ||
    cardholder.length > 100 ||
    !validDemoCard(cardDigits) ||
    !validExpiry(req.body.expiry) ||
    !/^\d{3}$/.test(req.body.cvv?.toString() ?? "")
  ) {
    return res.status(400).json({
      message: "Use valid demo card details. No real card is accepted by this simulator.",
    });
  }

  const connection = await db.getConnection();
  let transactionStarted = false;
  try {
    await connection.beginTransaction();
    transactionStarted = true;

    const [existing] = await connection.execute(
      `SELECT id, consultation_id, amount, currency, status, reference, card_last_four
       FROM simulated_transactions
       WHERE idempotency_key = ? AND user_id = ?
       LIMIT 1`,
      [idempotencyKey, req.user.id],
    );
    if (existing.length > 0) {
      await connection.commit();
      transactionStarted = false;
      return res.status(200).json({
        message: "This payment attempt was already processed.",
        transaction: existing[0],
        consultationId: existing[0].consultation_id,
      });
    }

    const [patients] = await connection.execute(
      "SELECT id FROM patients WHERE user_id = ? LIMIT 1 FOR UPDATE",
      [req.user.id],
    );
    if (patients.length === 0) {
      await connection.rollback();
      transactionStarted = false;
      return res.status(404).json({ message: "Patient profile not found." });
    }

    const [settings] = await connection.execute(
      `SELECT setting_value
       FROM system_settings
       WHERE setting_key = 'symptom_consultation_amount_dzd'
       LIMIT 1`,
    );
    if (settings.length === 0) {
      await connection.rollback();
      transactionStarted = false;
      return res.status(409).json({
        message: "Symptom consultation is unavailable until an administrator configures its DZD price.",
      });
    }
    const amount = Number(settings[0].setting_value);
    if (!Number.isSafeInteger(amount) || amount <= 0) {
      throw new Error("Configured consultation price is invalid.");
    }

    if (doctorId !== null) {
      const [doctors] = await connection.execute(
        "SELECT id FROM users WHERE id = ? AND role = 'doctor' LIMIT 1",
        [doctorId],
      );
      if (doctors.length === 0) {
        await connection.rollback();
        transactionStarted = false;
        return res.status(400).json({ message: "Selected doctor was not found." });
      }
    }

    const succeeded = cardDigits === DEMO_SUCCESS_CARD;
    const status = succeeded ? "succeeded" : "failed";
    const reference = `DEMO-${crypto.randomBytes(8).toString("hex").toUpperCase()}`;
    let consultationId = null;
    if (succeeded) {
      const [consultation] = await connection.execute(
        `INSERT INTO consultations (patient_id, doctor_id, symptoms, notes, status)
         VALUES (?, ?, ?, ?, 'paid')`,
        [patients[0].id, doctorId, symptoms, notes || null],
      );
      consultationId = consultation.insertId;
    }

    const [payment] = await connection.execute(
      `INSERT INTO simulated_transactions
         (user_id, consultation_id, amount, currency, status, reference,
          idempotency_key, card_last_four)
       VALUES (?, ?, ?, 'DZD', ?, ?, ?, ?)`,
      [
        req.user.id,
        consultationId,
        amount,
        status,
        reference,
        idempotencyKey,
        cardDigits.slice(-4),
      ],
    );
    await connection.commit();
    transactionStarted = false;

    if (succeeded && doctorId !== null) {
      await createNotification(
        doctorId,
        "New paid symptom consultation",
        "A patient submitted a DEMO-paid symptom consultation.",
        "symptom_consultation",
        consultationId,
      );
    }

    return res.status(succeeded ? 201 : 200).json({
      message: succeeded
        ? "DEMO payment succeeded. No real money was transferred."
        : "DEMO payment declined. No consultation was created.",
      transaction: {
        id: payment.insertId,
        status,
        amount,
        currency: "DZD",
        reference,
        card_last_four: cardDigits.slice(-4),
      },
      consultationId,
    });
  } catch (err) {
    if (transactionStarted) await connection.rollback();
    if (err.code === "ER_DUP_ENTRY") {
      try {
        const [existing] = await db.execute(
          `SELECT id, consultation_id, amount, currency, status, reference, card_last_four
           FROM simulated_transactions
           WHERE idempotency_key = ? AND user_id = ?
           LIMIT 1`,
          [idempotencyKey, req.user.id],
        );
        if (existing.length > 0) {
          return res.status(200).json({
            message: "This payment attempt was already processed.",
            transaction: existing[0],
            consultationId: existing[0].consultation_id,
          });
        }
      } catch (lookupError) {
        console.error("Look up duplicate payment attempt error:", lookupError);
        return res.status(500).json({ message: "Unable to verify the demo payment attempt." });
      }
    }
    console.error("Create simulated consultation payment error:", err);
    return res.status(500).json({ message: "Unable to process the demo payment." });
  } finally {
    connection.release();
  }
};

const getMyConsultations = async (req, res) => {
  if (req.user.role !== "patient") {
    return res.status(403).json({ message: "Access denied." });
  }
  try {
    const [rows] = await db.execute(
      `SELECT c.id, c.symptoms, c.notes, c.status, c.created_at,
              d.name AS doctor_name, st.amount, st.currency, st.reference,
              st.status AS payment_status, st.card_last_four
       FROM consultations c
       JOIN patients p ON p.id = c.patient_id
       JOIN simulated_transactions st ON st.consultation_id = c.id
       LEFT JOIN users d ON d.id = c.doctor_id
       WHERE p.user_id = ?
       ORDER BY c.created_at DESC`,
      [req.user.id],
    );
    return res.status(200).json({ consultations: rows });
  } catch (err) {
    console.error("Get patient consultations error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

const getDoctorConsultations = async (req, res) => {
  if (req.user.role !== "doctor") {
    return res.status(403).json({ message: "Only doctors can view assigned consultations." });
  }
  try {
    const [rows] = await db.execute(
      `SELECT c.id, c.symptoms, c.notes, c.status, c.created_at,
              p.firstname, p.lastname, p.age, p.sex,
              st.amount, st.currency, st.reference
       FROM consultations c
       JOIN patients p ON p.id = c.patient_id
       JOIN simulated_transactions st ON st.consultation_id = c.id
       WHERE c.doctor_id = ? AND st.status = 'succeeded'
       ORDER BY c.created_at DESC`,
      [req.user.id],
    );
    return res.status(200).json({ consultations: rows });
  } catch (err) {
    console.error("Get doctor consultations error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

const updateConsultationStatus = async (req, res) => {
  if (req.user.role !== "doctor") {
    return res.status(403).json({ message: "Only doctors can update consultations." });
  }
  const id = Number.parseInt(req.params.id, 10);
  const status = req.body.status;
  if (!Number.isInteger(id) || id <= 0 || !["in_progress", "completed"].includes(status)) {
    return res.status(400).json({ message: "Consultation update is invalid." });
  }
  try {
    const [result] = await db.execute(
      `UPDATE consultations SET status = ?
       WHERE id = ? AND doctor_id = ? AND status IN ('paid', 'in_progress')`,
      [status, id, req.user.id],
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Consultation not found or unavailable." });
    }
    return res.status(200).json({ message: "Consultation status updated." });
  } catch (err) {
    console.error("Update consultation status error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

module.exports = {
  getPrice,
  createPaidConsultation,
  getMyConsultations,
  getDoctorConsultations,
  updateConsultationStatus,
  validDemoCard,
  validExpiry,
};
