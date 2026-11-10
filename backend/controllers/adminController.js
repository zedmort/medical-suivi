const db = require("../config/db");
const upload = require("../config/multer");
const { isValidSpecialty } = require("../config/medicalTaxonomy");

const isValidUrl = (value) => {
  if (!value) return true;
  try {
    return ["http:", "https:"].includes(new URL(value).protocol);
  } catch {
    return false;
  }
};

const parseId = (value) => {
  const id = Number.parseInt(value, 10);
  return Number.isInteger(id) && id > 0 ? id : null;
};

const getSettings = async (_req, res) => {
  try {
    const [rows] = await db.execute(
      `SELECT setting_value, updated_at
       FROM system_settings
       WHERE setting_key = 'symptom_consultation_amount_dzd'
       LIMIT 1`,
    );
    return res.status(200).json({
      symptomConsultationAmountDzd: rows.length
        ? Number(rows[0].setting_value)
        : null,
      updatedAt: rows[0]?.updated_at || null,
    });
  } catch (err) {
    console.error("Get admin settings error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

const uploadAdImage = (req, res) => {
  if (!req.file) {
    return res.status(400).json({ message: "An advertisement image is required." });
  }
  return res.status(201).json({ image_url: upload.getFileUrl(req.file) });
};

const updateConsultationPrice = async (req, res) => {
  const amount = Number(req.body.amount_dzd);
  if (!Number.isSafeInteger(amount) || amount <= 0 || amount > 100000000) {
    return res.status(400).json({
      message: "amount_dzd must be a positive whole-number DZD amount.",
    });
  }
  try {
    await db.execute(
      `INSERT INTO system_settings (setting_key, setting_value, updated_by)
       VALUES ('symptom_consultation_amount_dzd', ?, ?)
       ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value),
                               updated_by = VALUES(updated_by)`,
      [String(amount), req.user.id],
    );
    return res.status(200).json({
      message: "Consultation price updated.",
      amountDzd: amount,
      currency: "DZD",
    });
  } catch (err) {
    console.error("Update consultation price error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

const listTransactions = async (req, res) => {
  const limit = Math.min(Math.max(parseId(req.query.limit) || 50, 1), 200);
  const offset = Math.max(Number.parseInt(req.query.offset, 10) || 0, 0);
  try {
    const [rows] = await db.execute(
      `SELECT st.id, st.user_id, u.name AS patient_name, st.consultation_id,
              st.amount, st.currency, st.status, st.reference,
              st.card_last_four, st.created_at
       FROM simulated_transactions st
       JOIN users u ON u.id = st.user_id
       ORDER BY st.created_at DESC
       LIMIT ? OFFSET ?`,
      [limit, offset],
    );
    return res.status(200).json({ transactions: rows });
  } catch (err) {
    console.error("List simulated transactions error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

const listAds = async (_req, res) => {
  try {
    const [rows] = await db.execute(
      `SELECT id, title, description, image_url, destination_url, placement,
              starts_at, expires_at, is_active, impressions, clicks, created_at, updated_at
       FROM advertisements
       ORDER BY created_at DESC`,
    );
    return res.status(200).json({ advertisements: rows });
  } catch (err) {
    console.error("List advertisements error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

const saveAd = async (req, res) => {
  const id = req.params.id ? parseId(req.params.id) : null;
  const {
    title,
    description,
    image_url,
    destination_url,
    placement = "dashboard",
    starts_at,
    expires_at,
  } = req.body;
  if (
    (req.params.id && !id) ||
    !title?.toString().trim() ||
    title.toString().trim().length > 180 ||
    !["dashboard", "patient_dashboard", "doctor_dashboard", "labo_dashboard", "pharmacy_dashboard"].includes(placement) ||
    !isValidUrl(destination_url) ||
    (image_url && !image_url.startsWith("/uploads/") && !isValidUrl(image_url))
  ) {
    return res.status(400).json({ message: "Advertisement fields are invalid." });
  }
  const start = starts_at ? new Date(starts_at) : null;
  const expires = expires_at ? new Date(expires_at) : null;
  if (
    (start && Number.isNaN(start.getTime())) ||
    (expires && Number.isNaN(expires.getTime())) ||
    (start && expires && expires <= start)
  ) {
    return res.status(400).json({ message: "Advertisement schedule is invalid." });
  }

  const fileUrl = req.file ? upload.getFileUrl(req.file) : image_url || null;
  try {
    if (id) {
      const [existing] = await db.execute(
        "SELECT id, image_url FROM advertisements WHERE id = ?",
        [id],
      );
      if (existing.length === 0) {
        return res.status(404).json({ message: "Advertisement not found." });
      }
      await db.execute(
        `UPDATE advertisements
         SET title = ?, description = ?, destination_url = ?, placement = ?,
             starts_at = ?, expires_at = ?, image_url = ?
         WHERE id = ?`,
        [
          title.toString().trim(),
          description?.toString().trim() || null,
          destination_url?.toString().trim() || null,
          placement,
          start,
          expires,
          fileUrl || existing[0].image_url,
          id,
        ],
      );
      return res.status(200).json({ message: "Advertisement updated.", id });
    }

    const [result] = await db.execute(
      `INSERT INTO advertisements
         (title, description, image_url, destination_url, placement,
          starts_at, expires_at, created_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        title.toString().trim(),
        description?.toString().trim() || null,
        fileUrl,
        destination_url?.toString().trim() || null,
        placement,
        start,
        expires,
        req.user.id,
      ],
    );
    return res.status(201).json({
      message: "Advertisement created. Activate it when ready.",
      id: result.insertId,
    });
  } catch (err) {
    console.error("Save advertisement error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

const updateAdStatus = async (req, res) => {
  const id = parseId(req.params.id);
  const isActive = req.body.is_active;
  if (!id || typeof isActive !== "boolean") {
    return res.status(400).json({ message: "A valid id and is_active flag are required." });
  }
  try {
    const [result] = await db.execute(
      "UPDATE advertisements SET is_active = ? WHERE id = ?",
      [isActive ? 1 : 0, id],
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Advertisement not found." });
    }
    return res.status(200).json({ message: "Advertisement status updated." });
  } catch (err) {
    console.error("Update advertisement status error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

const deleteAd = async (req, res) => {
  const id = parseId(req.params.id);
  if (!id) return res.status(400).json({ message: "Invalid advertisement id." });
  try {
    const [result] = await db.execute(
      "DELETE FROM advertisements WHERE id = ?",
      [id],
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Advertisement not found." });
    }
    return res.status(200).json({ message: "Advertisement deleted." });
  } catch (err) {
    console.error("Delete advertisement error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

const getConditionMappings = async (_req, res) => {
  try {
    const [rows] = await db.execute(
      `SELECT c.id, c.name, GROUP_CONCAT(DISTINCT s.slug ORDER BY s.slug SEPARATOR ',') AS specialties
       FROM medical_conditions c
       LEFT JOIN condition_specialties cs ON cs.condition_id = c.id
       LEFT JOIN specialties s ON s.id = cs.specialty_id
       GROUP BY c.id
       ORDER BY c.name`,
    );
    return res.status(200).json({
      mappings: rows.map((row) => ({
        id: row.id,
        condition: row.name,
        specialties: row.specialties ? row.specialties.split(",") : [],
      })),
    });
  } catch (err) {
    console.error("Get condition mappings error:", err);
    return res.status(500).json({ message: "Server error." });
  }
};

const updateConditionMappings = async (req, res) => {
  const conditionId = parseId(req.params.id);
  const selected = req.body.specialties;
  if (
    !conditionId ||
    !Array.isArray(selected) ||
    selected.some((specialty) => !isValidSpecialty(specialty))
  ) {
    return res.status(400).json({ message: "Condition mapping is invalid." });
  }
  const specialties = [...new Set(selected.map((item) => item.trim().toLowerCase()))];
  const connection = await db.getConnection();
  let transactionStarted = false;
  try {
    await connection.beginTransaction();
    transactionStarted = true;
    const [conditions] = await connection.execute(
      "SELECT id FROM medical_conditions WHERE id = ? FOR UPDATE",
      [conditionId],
    );
    if (conditions.length === 0) {
      await connection.rollback();
      transactionStarted = false;
      return res.status(404).json({ message: "Medical condition not found." });
    }
    await connection.execute(
      "DELETE FROM condition_specialties WHERE condition_id = ?",
      [conditionId],
    );
    for (const specialty of specialties) {
      const [result] = await connection.execute(
        `INSERT INTO condition_specialties (condition_id, specialty_id)
         SELECT ?, id FROM specialties WHERE slug = ?`,
        [conditionId, specialty],
      );
      if (result.affectedRows === 0) {
        throw new Error(`Unknown specialty: ${specialty}`);
      }
    }
    await connection.commit();
    transactionStarted = false;
    return res.status(200).json({ message: "Condition mapping updated." });
  } catch (err) {
    if (transactionStarted) await connection.rollback();
    console.error("Update condition mapping error:", err);
    return res.status(500).json({ message: "Server error." });
  } finally {
    connection.release();
  }
};

module.exports = {
  getSettings,
  uploadAdImage,
  updateConsultationPrice,
  listTransactions,
  listAds,
  saveAd,
  updateAdStatus,
  deleteAd,
  getConditionMappings,
  updateConditionMappings,
};
