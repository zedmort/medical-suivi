require('dotenv').config();
const bcrypt = require('bcrypt');
const db = require('../config/db');

async function main() {
  const email = process.env.ADMIN_EMAIL?.trim().toLowerCase();
  const password = process.env.ADMIN_PASSWORD;
  const name = process.env.ADMIN_NAME?.trim() || 'MediGo Admin';

  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new Error('Set ADMIN_EMAIL to a valid email address.');
  }
  if (!password || password.length < 14) {
    throw new Error('Set ADMIN_PASSWORD to a secret of at least 14 characters.');
  }

  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();
    const [existingAdmin] = await connection.execute(
      "SELECT id FROM users WHERE role = 'admin' LIMIT 1 FOR UPDATE",
    );
    if (existingAdmin.length > 0) {
      throw new Error('An admin account already exists; bootstrap will not replace it.');
    }

    const [existingEmail] = await connection.execute(
      'SELECT id FROM users WHERE email = ? LIMIT 1',
      [email],
    );
    if (existingEmail.length > 0) {
      throw new Error('The configured admin email is already in use.');
    }

    const passwordHash = await bcrypt.hash(password, 12);
    await connection.execute(
      `INSERT INTO users (name, email, password_hash, role, firstname, lastname)
       VALUES (?, ?, ?, 'admin', ?, ?)`,
      [name, email, passwordHash, name, ''],
    );
    await connection.commit();
    console.log(`Admin account created for ${email}.`);
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}

main()
  .catch((error) => {
    console.error(`Admin bootstrap failed: ${error.message}`);
    process.exitCode = 1;
  })
  .finally(async () => {
    await db.end();
  });
