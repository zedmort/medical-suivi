require('dotenv').config();
const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');
const {
  SPECIALTY_DISEASES,
  getSpecialties,
  getAllDiseases,
} = require('../config/medicalTaxonomy');

function resolveDbConfig() {
  if (process.env.DATABASE_URL || process.env.MYSQL_URL) {
    return {
      uri: process.env.DATABASE_URL || process.env.MYSQL_URL,
    };
  } 

  return {
    host: process.env.DB_HOST || process.env.MYSQLHOST || 'localhost',
    port: parseInt(process.env.DB_PORT || process.env.MYSQLPORT || '3306', 10),
    user: process.env.DB_USER || process.env.MYSQLUSER || 'root',
    password: process.env.DB_PASSWORD || process.env.MYSQLPASSWORD || '',
    database: process.env.DB_NAME || process.env.MYSQL_DATABASE || 'railway',
    charset: 'utf8mb4',
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : undefined,
  };
}

async function main() {
  const schemaPath = path.join(__dirname, '..', 'config', 'schema.sql');
  const schema = fs.readFileSync(schemaPath, 'utf8');

  const connectionConfig = resolveDbConfig();

  const connection = await mysql.createConnection({
    ...connectionConfig,
    multipleStatements: true,
  });

  try {
    await connection.query(schema);
    await migrateExistingSchema(connection);
    await seedMedicalTaxonomy(connection);
    console.log('Migration complete.');
  } finally {
    await connection.end();
  }
}

async function migrateExistingSchema(connection) {
  const additions = {
    users: [
      ['firstname', 'VARCHAR(100) NULL'],
      ['lastname', 'VARCHAR(100) NULL'],
      ['date_of_birth', 'DATE NULL'],
      ['address', 'TEXT NULL'],
      ['phone', 'VARCHAR(30) NULL'],
      ['doctor_type', "ENUM('general_practitioner', 'specialist') NULL"],
      ['professional_info', 'TEXT NULL'],
    ],
    patients: [['date_of_birth', 'DATE NULL']],
  };

  for (const [table, columns] of Object.entries(additions)) {
    for (const [column, definition] of columns) {
      const [rows] = await connection.execute(
        `SELECT COUNT(*) AS count
         FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?`,
        [table, column],
      );
      if (rows[0].count === 0) {
        await connection.query(
          `ALTER TABLE \`${table}\` ADD COLUMN \`${column}\` ${definition}`,
        );
      }
    }
  }

  await connection.query(
    `ALTER TABLE users
     MODIFY COLUMN role ENUM('doctor', 'patient', 'labo', 'pharmacy', 'admin') NOT NULL`,
  );
}

async function seedMedicalTaxonomy(connection) {
  for (const slug of getSpecialties()) {
    await connection.execute(
      'INSERT IGNORE INTO specialties (slug, name) VALUES (?, ?)',
      [slug, slug],
    );
  }

  for (const name of getAllDiseases()) {
    await connection.execute(
      'INSERT IGNORE INTO medical_conditions (name) VALUES (?)',
      [name],
    );
  }

  for (const [slug, conditions] of Object.entries(SPECIALTY_DISEASES)) {
    for (const name of conditions) {
      await connection.execute(
        `INSERT IGNORE INTO condition_specialties (condition_id, specialty_id)
         SELECT c.id, s.id
         FROM medical_conditions c
         JOIN specialties s ON s.slug = ?
         WHERE c.name = ?`,
        [slug, name],
      );
    }
  }

  await connection.query(
    `INSERT IGNORE INTO doctor_specialties (doctor_id, specialty_id)
     SELECT u.id, s.id
     FROM users u
     JOIN specialties s ON s.slug = LOWER(TRIM(u.specialty))
     WHERE u.role = 'doctor' AND u.specialty IS NOT NULL AND u.specialty <> ''`,
  );

  await connection.query(
    `INSERT IGNORE INTO patient_conditions (patient_id, condition_id)
     SELECT p.id, c.id
     FROM patients p
     JOIN medical_conditions c ON c.name = p.disease
     WHERE p.disease IS NOT NULL AND p.disease <> ''`,
  );
}

main().catch((error) => {
  console.error('Migration failed:', error.message);
  process.exit(1);
});
