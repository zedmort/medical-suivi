const db = require("../config/db");

const findPatientForUser = async (user, connection = db) => {
  const [linkedRows] = await connection.execute(
    "SELECT id FROM patients WHERE user_id = ? LIMIT 1",
    [user.id],
  );
  if (linkedRows[0]) return linkedRows[0];

  let name = user.name;
  if (!name && user.id) {
    const [userRows] = await connection.execute(
      "SELECT name FROM users WHERE id = ? AND role = 'patient' LIMIT 1",
      [user.id],
    );
    name = userRows[0]?.name;
  }
  if (!name) return null;
  const [legacyRows] = await connection.execute(
    `SELECT p.id
     FROM patients p
     WHERE LOWER(TRIM(CONCAT(p.firstname, ' ', p.lastname))) = LOWER(TRIM(?))
       AND (SELECT COUNT(*) FROM patients p2
            WHERE LOWER(TRIM(CONCAT(p2.firstname, ' ', p2.lastname))) = LOWER(TRIM(?))) = 1
       AND (SELECT COUNT(*) FROM users u
            WHERE u.role = 'patient' AND LOWER(TRIM(u.name)) = LOWER(TRIM(?))) = 1
     LIMIT 1`,
    [name, name, name],
  );
  return legacyRows[0] || null;
};

const findUserIdForPatient = async (patientId, connection = db) => {
  const [rows] = await connection.execute(
    `SELECT p.user_id AS id,
            CONCAT(p.firstname, ' ', p.lastname) AS full_name
     FROM patients p
     WHERE p.id = ?
     LIMIT 1`,
    [patientId],
  );
  if (!rows[0]) return null;
  if (rows[0].id) return rows[0].id;

  const name = rows[0].full_name;
  const [legacyRows] = await connection.execute(
    `SELECT u.id
     FROM users u
     WHERE u.role = 'patient' AND LOWER(TRIM(u.name)) = LOWER(TRIM(?))
       AND (SELECT COUNT(*) FROM users u2
            WHERE u2.role = 'patient' AND LOWER(TRIM(u2.name)) = LOWER(TRIM(?))) = 1
       AND (SELECT COUNT(*) FROM patients p2
            WHERE LOWER(TRIM(CONCAT(p2.firstname, ' ', p2.lastname))) = LOWER(TRIM(?))) = 1
     LIMIT 1`,
    [name, name, name],
  );
  return legacyRows[0]?.id || null;
};

module.exports = { findPatientForUser, findUserIdForPatient };
